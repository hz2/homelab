use anyhow::Result;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("camera.v1");
}

use proto::{
    camera_service_server::{CameraService, CameraServiceServer},
    DetectionEvent, ListCamerasRequest, ListCamerasResponse, StreamEventsRequest,
};

struct CameraServiceImpl;

#[tonic::async_trait]
impl CameraService for CameraServiceImpl {
    async fn list_cameras(
        &self,
        _req: Request<ListCamerasRequest>,
    ) -> Result<Response<ListCamerasResponse>, Status> {
        Ok(Response::new(ListCamerasResponse { cameras: vec![] }))
    }

    type StreamEventsStream = ReceiverStream<Result<DetectionEvent, Status>>;

    async fn stream_events(
        &self,
        _req: Request<StreamEventsRequest>,
    ) -> Result<Response<Self::StreamEventsStream>, Status> {
        let (_tx, rx) = tokio::sync::mpsc::channel(1);
        Ok(Response::new(ReceiverStream::new(rx)))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let addr = "[::]:50052".parse()?;
    tracing::info!("camera listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(CameraServiceServer::new(CameraServiceImpl)))
        .serve(addr)
        .await?;
    Ok(())
}
