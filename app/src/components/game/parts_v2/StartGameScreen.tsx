// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

export function StartGameScreen({
  disabled,
  start,
}: {
  disabled: boolean;
  start: (force?: boolean) => void;
}) {
  return (
    <div className="text-center py-12">
      <p>
        Welcome back! Click the following button to automatically find someone
        to play with.
      </p>
      <div className="grid md:flex gap-5 justify-center py-6">
        <button
          onClick={() => {
            start(true);
          }}
          disabled={disabled}
        >
          Find a match
        </button>
      </div>
    </div>
  );
}
