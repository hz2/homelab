use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_root = std::env::var("PROTO_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../proto"));
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(&[proto_root.join("camera/v1/camera.proto")], &[&proto_root])?;
    Ok(())
}
