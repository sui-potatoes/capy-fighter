// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

export type ArenaResultProps = {
  result: string | null;
  end: () => void;
};

export function ArenaResult({ result, end }: ArenaResultProps) {
  if (!result) return null;
  return (
    <div>
      <h2 className="text-6xl mb-6">{result}</h2>
      <button onClick={end}>Play Again</button>
    </div>
  );
}
