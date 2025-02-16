use axum::{
    Router,
    routing::{get, get_service},
};
use buck_resources::get_resource;
use tower_http::services::{ServeDir, ServeFile};

fn using_serve_dir() -> Router {
    let mut js_asset_path = get_resource("backend/bundle.js").unwrap();
    let mut index_asset_path = get_resource("backend/index.html").unwrap();
    Router::new()
        .route("/index.html", get_service(ServeFile::new(index_asset_path)))
        .route(
            "/assets/main.js",
            get_service(ServeFile::new(js_asset_path)),
        )
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let app = using_serve_dir();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app.into_make_service()).await?;

    Ok(())
}
