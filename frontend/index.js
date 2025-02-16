import React from "react";
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from "react-router";

function App() {
  return (
    <div>Hello, from buck2 w/ react! </div>
  );
}

const container = document.getElementById('root');
const root = createRoot(container);

root.render(
  <BrowserRouter>
    <App />
  </BrowserRouter>
);
