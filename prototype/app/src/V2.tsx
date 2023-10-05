// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useState } from "react";
import "./App.css";
import { Register } from "./components/Register";
import { ActionBar } from "./components/ActionBar";
import { GameV2 } from "./components/game/GameV2";

function AppV2() {
  const [email, setEmail] = useState<string>(
    localStorage.getItem("email") || ""
  );
  const [connected, setConnected] = useState<boolean>(
    !!localStorage.getItem("email")
  );

  const login = () => {
    localStorage.setItem("email", email);
    setConnected(true);
  };

  const logout = () => {
    localStorage.setItem("email", "");
    setEmail("");
    setConnected(false);
  };

  return (
    <>
      <div className="items-center max-md:grid overflow-hidden justify-center py-1 md:px-12">
        <div className="order-2 lg:order-1 max-md:py-12 max-md:border-t">
          <div className="pb-3 text-2xl tracking-widest font-medium text-center">
            Welcome to Capy Arcade.
          </div>
          {connected && <ActionBar email={email} logout={logout} />}
        </div>

        <div className="order-1 lg:order-2">
          {!connected && (
            <Register email={email} setEmail={setEmail} login={login} />
          )}
          {connected && <GameV2 />}
        </div>
      </div>
    </>
  );
}

export default AppV2;
