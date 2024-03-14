import { ConnectButton } from "@mysten/dapp-kit";


function App() {
  return (
    <>
      <div className="container">
        <div className="sidebar">
          <p className="wallet connect"><u><ConnectButton className="connect" connectText="Connect" /></u></p>
          <ul>
            <li>KIOSK</li>
            <li>EXTENSIONS</li>
            <li>CONTENTS</li>
            <li>INTERFACE</li>
            <li className="active">REMAPPING</li>
          </ul>
        </div>
        <div className="content">
          <p><img src="/kiosk.png" alt="Kiosk" /></p>
          {/* <div className="controls">
            <div className="control-item">
              <span>Move</span>
              <div className="buttons"><button>⬆</button></div>
            </div>
          </div> */}
          {/* <div className="advanced">
            <div className="control-item">
              <span>Dodge</span>
              <div className="buttons"><button>⭘</button></div>
            </div>
          </div> */}
        </div>
      </div>
      {/* <Flex
        position="sticky"
        px="4"
        py="2"
        justify="between"
        style={{
          borderBottom: "1px solid var(--gray-a2)",
        }}
      >
        <Box>
          <Heading>dApp Starter Template</Heading>
        </Box>

        <Box>

        </Box>
      </Flex>
      <Container>
        <Container
          mt="5"
          pt="2"
          px="4"
          style={{ background: "var(--gray-a2)", minHeight: 500 }}
        >
          <WalletStatus />
        </Container>
      </Container> */}
    </>
  );
}

export default App;
