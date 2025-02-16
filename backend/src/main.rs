use tower_http::{
    services::{ServeDir, ServeFile},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let app = repo::router();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app.into_make_service()).await?;

    Ok(())
}
