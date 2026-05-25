use anyhow::Result;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("sensor.v1");
}

use proto::{
    sensor_service_server::{SensorService, SensorServiceServer},
    ListSensorsRequest, ListSensorsResponse, SensorReading, StreamReadingsRequest,
};

struct SensorServiceImpl;

#[tonic::async_trait]
impl SensorService for SensorServiceImpl {
    async fn list_sensors(
        &self,
        _req: Request<ListSensorsRequest>,
    ) -> Result<Response<ListSensorsResponse>, Status> {
        Ok(Response::new(ListSensorsResponse { sensors: vec![] }))
    }

    type StreamReadingsStream = ReceiverStream<Result<SensorReading, Status>>;

    async fn stream_readings(
        &self,
        _req: Request<StreamReadingsRequest>,
    ) -> Result<Response<Self::StreamReadingsStream>, Status> {
        let (_tx, rx) = tokio::sync::mpsc::channel(1);
        Ok(Response::new(ReceiverStream::new(rx)))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let addr = "[::]:50051".parse()?;
    tracing::info!("sensor listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(SensorServiceServer::new(SensorServiceImpl)))
        .serve(addr)
        .await?;
    Ok(())
}
