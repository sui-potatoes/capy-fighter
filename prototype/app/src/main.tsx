import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import AppV2 from './V2.tsx';
import AppV1 from './V1.tsx';

const router = createBrowserRouter([
  {
    path: "/",
    element: <AppV2 />,
  },
  {
    path: "/v1",
    element: <AppV1 />,
  }
]);

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
)
