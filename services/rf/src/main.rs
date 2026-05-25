use anyhow::Result;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("rf.v1");
}

use proto::{
    rf_service_server::{RfService, RfServiceServer},
    ListEventsRequest, ListEventsResponse, RfEvent, StreamEventsRequest,
};

struct RfServiceImpl;

#[tonic::async_trait]
impl RfService for RfServiceImpl {
    async fn list_events(
        &self,
        _req: Request<ListEventsRequest>,
    ) -> Result<Response<ListEventsResponse>, Status> {
        Ok(Response::new(ListEventsResponse { events: vec![] }))
    }

    type StreamEventsStream = ReceiverStream<Result<RfEvent, Status>>;

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
    let addr = "[::]:50053".parse()?;
    tracing::info!("rf listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(RfServiceServer::new(RfServiceImpl)))
        .serve(addr)
        .await?;
    Ok(())
}
