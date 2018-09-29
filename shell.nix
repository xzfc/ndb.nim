{ v ? "0.19.0" }:
with import <nixpkgs> {};
let
  nim-common = version: sha256:
    nim.overrideAttrs (attrs: rec {
      name = "nim-${version}";
      inherit version;
      src = fetchurl {
        url = "https://nim-lang.org/download/${name}.tar.xz";
        inherit sha256;
      };

      doCheck = false;
      postPatch = '' rm -rf tests '';
      buildPhase = ''export LD=$CC XDG_CACHE_HOME=$PWD/.cache;'' + attrs.buildPhase;
    });
    nim-versions = {
      "0.19.0" = nim-common "0.19.0" "0biwvw1gividp5lkf0daq1wp9v6ms4xy6dkf5zj0sn9w4m3n76d1";
      "0.18.0" = nim-common "0.18.0" "1l1vdygbgs5fdh2ffdjapcp90p8f6cbsw4hivndgm3gh6pdlmis5";
      "0.17.0" = nim-common "0.17.0" "16vsmk4rqnkg9lc9h9jk62ps0x778cdqg6qrs3k6fv2g73cqvq9n";
      "0.16.0" = nim-common "0.16.0" "0rsibhkc5n548bn9yyb9ycrdgaph5kq84sfxc9gabjs7pqirh6cy";
    };
    nim-current = builtins.getAttr v nim-versions;
in
stdenv.mkDerivation {
  name = "db_sqlite_ex-shell";
  buildInputs = [ sqlite ];
  nativeBuildInputs = [ nim-current ];
  LD_LIBRARY_PATH = ''${sqlite.out}/lib'';
}
