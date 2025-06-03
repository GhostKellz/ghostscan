use clap::Parser;
use colored::*;
use futures::stream::{FuturesUnordered, StreamExt};
use serde::Serialize;
use std::net::{IpAddr, SocketAddr};
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;
use cidr_utils::cidr::Ipv4Cidr;
use indicatif::{ProgressBar, ProgressStyle};
use config::{Config, File};
use std::fs::File as StdFile;
use std::io::Write as IoWrite;
use std::collections::HashMap;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None, after_help = "\nEXAMPLES:\n  gscan 192.168.1.1\n  gscan 10.0.0.1-10.0.0.10 -p 20-1024 --output json\n  gscan 2001:db8::1 --ipv6\n")]
struct Args {
    /// Target IP, CIDR, or range (e.g. 192.168.1.1, 192.168.1.0/24, 192.168.1.1-192.168.1.10)
    target: String,
    /// Start port
    #[arg(short, long, default_value_t = 1)]
    start_port: u16,
    /// End port
    #[arg(short, long, default_value_t = 1024)]
    end_port: u16,
    /// Concurrency (parallel scans)
    #[arg(long, default_value_t = 64)]
    concurrency: usize,
    /// Timeout per port (ms)
    #[arg(long, default_value_t = 200)]
    timeout_ms: u64,
    /// Output format: text, json, csv
    #[arg(long, default_value = "text")]
    output: String,
    /// Output file
    #[arg(long)]
    output_file: Option<String>,
    /// Enable banner grabbing
    #[arg(long, default_value_t = false)]
    banner: bool,
    /// Rate limit (connections/sec)
    #[arg(long, default_value_t = 0)]
    rate: u64,
    /// Use IPv6
    #[arg(long, default_value_t = false)]
    ipv6: bool,
    /// Use config file
    #[arg(long)]
    config: Option<String>,
    /// Launch TUI/interactive mode
    #[arg(long, default_value_t = false)]
    tui: bool,
}

#[derive(Serialize)]
pub struct ScanResult {
    ip: String,
    port: u16,
    state: String,
    banner: Option<String>,
}

pub trait ScanPlugin: Send + Sync {
    fn process(&self, result: &ScanResult) -> Option<String>;
}

fn service_name(port: u16) -> &'static str {
    match port {
        21 => "ftp",
        22 => "ssh",
        23 => "telnet",
        25 => "smtp",
        53 => "dns",
        80 => "http",
        110 => "pop3",
        143 => "imap",
        443 => "https",
        3306 => "mysql",
        5432 => "postgres",
        6379 => "redis",
        8080 => "http-alt",
        _ => "?",
    }
}

#[tokio::main]
async fn main() {
    let mut args = Args::parse();
    // Config file support (fix deprecation and try_into usage)
    if let Some(cfg) = &args.config {
        let settings = Config::builder()
            .add_source(File::with_name(cfg))
            .build()
            .unwrap();
        let map: HashMap<String, String> = settings.try_deserialize().unwrap();
        if let Some(v) = map.get("concurrency") {
            args.concurrency = v.parse().unwrap_or(args.concurrency);
        }
        if let Some(v) = map.get("timeout_ms") {
            args.timeout_ms = v.parse().unwrap_or(args.timeout_ms);
        }
        if let Some(v) = map.get("output") {
            args.output = v.clone();
        }
        if let Some(v) = map.get("banner") {
            args.banner = v.parse().unwrap_or(args.banner);
        }
        if let Some(v) = map.get("rate") {
            args.rate = v.parse().unwrap_or(args.rate);
        }
    }
    if args.tui {
        println!("[TUI mode not yet implemented]");
        return;
    }
    let targets = parse_targets(&args.target, args.ipv6);
    let mut results = Vec::new();
    let mut open_ports = Vec::new();
    let mut _scanned = 0;
    let total = targets.len() * (args.end_port - args.start_port + 1) as usize;
    let pb = ProgressBar::new(total as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("[{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({percent}%)")
            .unwrap(),
    );
    for ip in targets {
        let mut futs = FuturesUnordered::new();
        for port in args.start_port..=args.end_port {
            let ip = ip.clone();
            let timeout_ms = args.timeout_ms;
            let banner = args.banner;
            futs.push(tokio::spawn(async move {
                let addr = SocketAddr::new(ip, port);
                let state;
                let mut banner_str = None;
                let res = timeout(Duration::from_millis(timeout_ms), TcpStream::connect(addr)).await;
                if let Ok(Ok(stream)) = res {
                    state = "open";
                    if banner {
                        let mut buf = [0u8; 64];
                        if let Ok(_) = timeout(Duration::from_millis(timeout_ms), stream.readable()).await {
                            if let Ok(n) = stream.try_read(&mut buf) {
                                if n > 0 {
                                    banner_str = Some(String::from_utf8_lossy(&buf[..n]).to_string());
                                }
                            }
                        }
                    }
                } else if let Ok(Err(e)) = res {
                    state = "error";
                    eprintln!("[{}:{}] Connection error: {}", ip, port, e);
                } else if res.is_err() {
                    state = "timeout";
                    eprintln!("[{}:{}] Timeout", ip, port);
                } else {
                    state = "closed";
                }
                ScanResult {
                    ip: addr.ip().to_string(),
                    port,
                    state: state.to_string(),
                    banner: banner_str,
                }
            }));
            if args.rate > 0 {
                tokio::time::sleep(Duration::from_millis(1000 / args.rate.max(1))).await;
            }
            if futs.len() >= args.concurrency {
                if let Some(res) = futs.next().await {
                    let r = res.unwrap();
                    _scanned += 1;
                    pb.inc(1);
                    if r.state == "open" {
                        open_ports.push((r.ip.clone(), r.port));
                    }
                    results.push(r);
                }
            }
        }
        while let Some(res) = futs.next().await {
            let r = res.unwrap();
            _scanned += 1;
            pb.inc(1);
            if r.state == "open" {
                open_ports.push((r.ip.clone(), r.port));
            }
            results.push(r);
        }
    }
    pb.finish_and_clear();
    match args.output.as_str() {
        "json" => {
            let out = serde_json::to_string_pretty(&results).unwrap();
            if let Some(path) = &args.output_file {
                let mut f = StdFile::create(path).unwrap();
                f.write_all(out.as_bytes()).unwrap();
            } else {
                println!("{}", out);
            }
        }
        "csv" => {
            let mut out = String::from("ip,port,state,banner\n");
            for r in &results {
                out.push_str(&format!(
                    "{},{},{},{}\n",
                    r.ip,
                    r.port,
                    r.state,
                    r.banner.as_deref().unwrap_or("")
                ));
            }
            if let Some(path) = &args.output_file {
                let mut f = StdFile::create(path).unwrap();
                f.write_all(out.as_bytes()).unwrap();
            } else {
                print!("{}", out);
            }
        }
        _ => {
            if open_ports.is_empty() {
                println!("{}", "No open ports found.".yellow());
            } else {
                for (ip, port) in open_ports {
                    println!("{}:{} {} {}", ip, port, "open".green(), service_name(port));
                }
            }
        }
    }
}

fn parse_targets(target: &str, ipv6: bool) -> Vec<IpAddr> {
    if !ipv6 {
        if let Ok(cidr) = target.parse::<Ipv4Cidr>() {
            return cidr.iter().map(|ip| IpAddr::V4(ip.into())).collect();
        }
        if let Some((start, end)) = target.split_once('-') {
            let start: IpAddr = start.parse().unwrap();
            let end: IpAddr = end.parse().unwrap();
            let mut ips = Vec::new();
            if let (IpAddr::V4(start), IpAddr::V4(end)) = (start, end) {
                let mut cur = u32::from(start);
                let end = u32::from(end);
                while cur <= end {
                    ips.push(IpAddr::V4(cur.into()));
                    cur += 1;
                }
            }
            return ips;
        }
        return vec![target.parse().unwrap()];
    } else {
        if let Some((start, end)) = target.split_once('-') {
            let start: IpAddr = start.parse().unwrap();
            let end: IpAddr = end.parse().unwrap();
            let mut ips = Vec::new();
            if let (IpAddr::V6(start), IpAddr::V6(end)) = (start, end) {
                let mut cur = u128::from(start);
                let end = u128::from(end);
                while cur <= end {
                    ips.push(IpAddr::V6(cur.into()));
                    cur += 1;
                }
            }
            return ips;
        }
        return vec![target.parse().unwrap()];
    }
}
