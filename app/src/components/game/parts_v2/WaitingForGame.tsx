// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

export function WaitingForGame({ cancel }: { cancel: () => void }) {
  return (
    <div className="text-center py-12">
      <p>Waiting for a matching game...</p>
      <button className="mt-3" onClick={cancel}>
        Cancel search
      </button>
    </div>
  );
}
