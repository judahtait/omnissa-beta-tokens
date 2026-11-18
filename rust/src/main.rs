use clap::Parser;
use omnissa_beta_tokens::cli::{self, Args};

fn main() {
    let args = Args::parse();
    std::process::exit(cli::run(args));
}
