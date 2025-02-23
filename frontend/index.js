import React from "react";
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from "react-router";

function App() {
  return (
    <div>Hello, from buck2 w/ react! </div>
  );
}

function App2() {
  return (
    <div>Goodbyee! </div>
  );
}

const container = document.getElementById('root');
const root = createRoot(container);

root.render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element=<App /> />
      <Route path="/exit" element=<App2 /> />
    </Routes>
  </BrowserRouter>
);
