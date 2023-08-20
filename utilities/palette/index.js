// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as path from "path";
import convert from "color-convert";

import c from "./palette.indexed.json" assert { type: "json" };

(function () {
  createGmp("carpets-150", [
    c.VandarPoelsBlue,
    c.CoralRed,
    c.SeashellPink,
    c.CalamineBlue,
    c.Sepia,
  ]);

  createGmp("carpets-151", [
    c.RainetteGreen,
    c.SeaGreen,
    c.SalviaBlue,
    c.NaplesYellow,
    c.SudanBrown,
    c.GrayishLavender,
  ]);

  createGmp("carpets-152", [
    c.VandarPoelsBlue,
    c.DarkMediciBlue,
    c.EosinePink,
    c.SeashellPink,
    c.PaleKingsBlue,
    c.OrangeYellow,
    c.DuskyGreen,
    c.Brown,
  ]);

  createGmp("carpets-153", [
    c.HaysRusset,
    c.PaleRawUmber,
    c.YellowOrange,
    c.LaeliaPink,
    c.EtruscanRed,
    c.PaleKingsBlue,
  ]);

  createGmp("carpets-154", [
    c.OrangeRufous,
    c.CreamYellow,
    c.GlaucousGreen,
    c.VandarPoelsBlue,
    c.LaeliaPink,
    c.CarmineRed,
    c.VioletBlue,
    c.White,
    c.Black,
  ]);

  createGmp("carpets-155", [
    c.VioletCarmine,
    c.OrangeCitrine,
    c.PyriteYellow,
    c.VandarPoelsBlue,
  ]);

  createGmp("carpets-156", [
    c.VandarPoelsBlue,
    c.OldRose,
    c.NaplesYellow,
    c.EnglishRed,
    c.MarsBrownTobacco,
  ]);

  createGmp("carpets-157", [c.Black, c.White, c.OchraceousSalmon]);

  createGmp("carpets-158", [
    c.OchraceousSalmon,
    c.NaplesYellow,
    c.OrangeCitrine,
    c.JasperRed,
    c.HelvetiaBlue,
  ]);
// })();
});

(function () {
  createGmp("september-049", [
    c.PaleEcruDrab,
    c.CotingaPurple,
    c.HermosaPink,
    c.HydrangeaRed,
  ]);

  createGmp("september-050", [
    c.PaleLemonYellow,
    c.DullCitrine,
    c.LightBrownishOlive,
  ]);

  createGmp("september-051", [
    c.Blue,
    c.DarkGreenishGlaucous,
    c.White,
    c.DuskyGreen,
    c.PistachioGreen,
  ]);

  createGmp("september-052", [
    c.SulphineYellow,
    c.DullVioletBlack,
    c.Blue,
  ]);

  createGmp("september-053", [
    c.DuskyGreen,
    c.CossackGreen,
    c.SpectrumRed,
    c.YellowGreen,
  ]);

  createGmp("september-054", [
    c.BuffyCitrine,
    c.PaleLemonYellow,
    c.LightBrownDrab,
    c.LightGlaucousBlue,
  ]);
// })();
});

(function () {
    let red = [
        c.PalePurplishVinaceous,
        c.HermosaPink,
        c.CorinthianPink,
        c.CameoPink,
        c.PaleCinnamonPink,
        c.Fawn,
        c.PaleEcruDrab,
        c.LightBrownDrab,
        c.CoralRed,
        c.FreshColor,
        c.GrenadinePink,
        c.EosinePink,
        c.SpinelRed,
        c.OldRose,
        c.EugeniaRed,
        c.EugeniaRed2,
        c.RawSienna,
        c.VinaceousTawny,
        c.JasperRed,
        c.SpectrumRed,
        c.RedOrange,
        c.EtruscanRed,
        c.BurntSienna,
        c.OcherRed,
        c.Scarlet,
        c.Carmine,
        c.IndianLake,
        c.RosolancPurple,
        c.PomegranatePurple,
        c.HydrangeaRed,
        c.BrickRed,
        c.CarmineRed,
        c.PompeianRed,
        c.Red,
        c.Brown,
        c.HaysRusset,
        c.VandykeRed,
        c.PansyPurple,
        c.PaleBurntLake,
        c.VioletRed,
        c.VistorisLake,
    ];

    let yellow = [
        c.SulphurYellow,
        c.SeafoamYellow,
        c.PaleLemonYellow,
        c.NaplesYellow,
        c.IvoryBuff,
        c.SeashellPink,
        c.LightPinkishCinnamon,
        c.PinkishCinnamon,
        c.CinnamonBuff,
        c.CreamYellow,
        c.GoldenYellow,
        c.VinaceousCinnamon,
        c.OchraceousSalmon,
        c.IsabellaColor,
        c.Maple,
        c.OliveBuff,
        c.Ecru,
        c.Yellow,
        c.LemonYellow,
        c.ApricotYellow,
        c.PyriteYellow,
        c.Olive0cher,
        c.YellowOcher,
        c.OrangeYellow,
        c.YellowOrange,
        c.ApricotOrange,
        c.Orange,
        c.PeachRed,
        c.EnglishRed,
        c.CinnamonRufous,
        c.OrangeRufous,
        c.SulphineYellow,
        c.Khaki,
        c.CitronYellow,
        c.Citrine,
        c.DullCitrine,
        c.BuffyCitrine,
        c.DarkCitrine,
        c.LightGrayishOlive,
        c.KronbergsGreen,
        c.Olive,
        c.OrangeCitrine,
        c.SudanBrown,
        c.OliveGreen,
        c.LightBrownishOlive,
        c.DeepGrayishOlive,
        c.PaleRawUmber,
        c.Sepia,
        c.MadderBrown,
        c.MarsBrownTobacco,
        c.VandykeBrown,
    ];

    let green = [
        c.TurquoiseGreen,
        c.GlaucousGreen,
        c.DarkGreenishGlaucous,
        c.PaleTurtleGreen,
        c.YellowGreen,
        c.LightGreenYellow,
        c.NightGreen,
        c.OliveYellow,
        c.ArtemisiaGreen,
        c.AndoverGreen,
        c.RainetteGreen,
        c.ChromiumGreen,
        c.PistachioGreen,
        c.SeaGreen,
        c.BenzolGreen,
        c.LightPorcelainGreen,
        c.Green,
        c.DullViridianGreen,
        c.OilGreen,
        c.GrapeGreen,
        c.DiamineGreen,
        c.CossackGreen,
        c.LincolnGreen,
        c.BlackishOlive,
        c.DeepSlateOlive,
    ];

    let blue = [
        c.PaleKingsBlue,
        c.NileBlue,
        c.PaleKingsBlue2,
        c.LightGlaucousBlue,
        c.SalviaBlue,
        c.CobaltGreen,
        c.CalamineBlue,
        c.VeniceGreen,
        c.PaleMethyBlue,
        c.CerulianBlue,
        c.PeacockBlue,
        c.GreenBlue,
        c.OlympicBlue,
        c.Blue,
        c.AntwarpBlue,
        c.HelvetiaBlue,
        c.DarkMediciBlue,
        c.DuskyGreen,
        c.DeepLyonsBlue,
        c.VioletBlue,
        c.VandarPoelsBlue,
        c.DarkTyrianBlue,
        c.DullVioletBlack,
        c.DeepIndigo, // >>>
        c.DeepSlateGreen,
    ];

    let violet = [
        c.GrayishLavender,
        c.GrayishLavender2, // >>>
        c.LaeliaPink,
        c.Lilac,
        c.EupatoriumPurple,
        c.LightMauve,
        c.AconiteViolet,
        c.DullBlueViolet,
        c.DarkSoftViolet,
        c.BlueViolet,
        c.VioletUltramarine,
        c.PurpleDrab,
        c.DeepVioletPlumbeous,
        c.VernoniaPurple,
        c.DarkSlatePurple,
        c.TaupeBrown,
        c.VioletCarmine,
        c.Violet,
        c.RedViolet,
        c.CotingaPurple,
        c.DuskyMadderViolet,
        c.DarkPerillaPurple,
        c.DullPurplishBlack,
    ];

    let grey = [
        c.White,
        c.NeutralGray,
        c.MineralGray,
        c.WarmGray,
        c.SlateColor,
        c.Black
    ];

    createGmp("red", red);
    createGmp("yellow", yellow);
    createGmp("green", green);
    createGmp("blue", blue);
    createGmp("violet", violet);
    createGmp("grey", grey);

    createGmp("sorted", [...red, ...yellow, ...green, ...blue, ...violet, ...grey]);
})();
// });

/**
 * Create an write a new .gmp file
 *
 * @param {*} name
 * @param {*} colors
 */
function createGmp(name, colors) {


  //  now prepare a GIMP palette file
  let gimp =
    `GIMP Palette
    # Name: ${name}
    # Based on: "A Dictionary of Color Combinations vol.2"
    #
` +
    colors
      .map((color) => {
        console.log(name, color);
        let [r, g, b] = color.rgb;
        let fmt = (v) => v.toString().padStart(3, " ");
        return `${fmt(r)} ${fmt(g)} ${fmt(b)}\t${color.name}`;
      })
      .join("\n");

  fs.writeFileSync(path.resolve("out", name + ".gpl"), gimp);
}

/**
 * Parse the raw scan file and create a cleaned up and converted JSON file.
 */
(function parseRaw() {
  let prev = "";
  let colors = [];

  fs.readFileSync("./raw.scan.txt")
    .toString("utf8")
    .split("\n")
    .forEach((line) => {
      if (/C[O0-9]+\sM[O0-9]+/.test(line)) {
        let search = /C([0-9]+) M([0-9]+) Y([0-9]+) K([0-9]+)/gim.exec(
          line.trim()
        );

        if (search == null) {
          console.log("failed: %s - %s", line, prev);
          console.log(
            /C([0-9]+) M([0-9]+) Y([0-9]+) K([0-9]+)/.test(line),
            /C([0-9]+) M([0-9]+) Y([0-9]+)/.test(line),
            /C([0-9]+) M([0-9]+)/.test(line),
            /C([0-9]+)/.test(line)
          );
          return;
        }

        let [_, c, m, y, k] = search;

        colors.push({
          name: prev.trim().replace("0", "O"),
          cmyk: line.trim(),
          hex: convert.cmyk.hex([c, m, y, k]),
          "#hex": "#" + convert.cmyk.hex([c, m, y, k]),
          rgb: convert.cmyk.rgb([c, m, y, k]),
        });
      }

      prev = line;
    });

  fs.writeFileSync(
    path.resolve("./palette.json"),
    JSON.stringify(colors, null, 4)
  );

  const indexedByName = colors.reduce((acc, color) => {
    acc[color.name.replace(/[^a-z0-9]/gi, "")] = color;
    return acc;
  }, {});

  console.log(colors.length);
  console.log(Object.keys(indexedByName).length);

  fs.writeFileSync(
    path.resolve("./palette.indexed.json"),
    JSON.stringify(indexedByName, null, 4)
  );
// })(); // add me to run the parser
});
