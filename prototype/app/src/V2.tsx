import { useState } from 'react'
import './App.css'
import { Register } from './components/Register'
import { ActionBar } from './components/ActionBar';
import { GameV2 } from './components/game/GameV2';

function AppV2() {

  const [email, setEmail] = useState<string>(localStorage.getItem('email') || '');
  const [connected, setConnected] = useState<boolean>(!!localStorage.getItem('email'));

  const login = () => {
    localStorage.setItem('email', email);
    setConnected(true);
  }

  const logout = () => {
    localStorage.setItem('email', '');
    setEmail('');
    setConnected(false);
  }

  return (
    <>
      <div className="items-center justify-center py-3 px-12">

        <div className="pb-3 text-2xl tracking-widest font-medium">
          Welcome to Capy Arcade.
        </div>

        {connected && <ActionBar email={email} logout={logout} /> }

        <div>
          {!connected && <Register email={email} setEmail={setEmail} login={login} />}
          {connected && <GameV2 />}
        </div>

      </div>
    </>
  )
}

export default AppV2
