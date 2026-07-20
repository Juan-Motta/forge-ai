// Palette sampled from the codeforge anvil icon.
export const theme = {
  bg: '#0d1526',       // navy background
  steel: '#7f9bb3',    // anvil body
  steelDim: '#3f5a63',
  molten: '#ff8a2b',   // incandescent orange (actions/accents)
  moltenHot: '#ffd23f',// hottest highlight
  cyan: '#39d7ff',     // </> / focus
  text: '#dbe4ee',
};
// `art` is a truecolor half-block string. When chafa is available at build time,
// replace the fallback below with its output for the pixel-art anvil.
export const art = process.env.CODEFORGE_NO_ART
  ? ''
  : String.raw`
        ${''}      </>
     _______________
    |###############|   c o d e f o r g e
    \_____________ /
      |         |
     /___________\
`;
