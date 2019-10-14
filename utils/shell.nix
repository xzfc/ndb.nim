{ v ? "1.0.0" }:
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
      prePatch = '' : '';
      buildPhase = ''export LD=$CC XDG_CACHE_HOME=$PWD/.cache;'' + attrs.buildPhase;
    });
  nim-git =
    stdenv.mkDerivation rec {
      name = "nim-${version}";
      version = "1.0.0-git";
    
      src = fetchFromGitHub {
        owner = "nim-lang";
        repo = "Nim";
        rev = "990aadc43c3b492a1df61582d5bd212a0643aee4";
        # 2019-10-14
        sha256 = "0yahyv8wxgsjpxk7548x82hgfi7cwj5jcca1hvfnnymdrxa2z8hj";
      };
      src-csources = fetchFromGitHub {
        owner = "nim-lang";
        repo = "csources";
        rev = "v0.20.0";
        sha256 = "0i6vsfy1sgapx43n226q8m0pvn159sw2mhp50zm3hhb9zfijanis";
      };
      src-nimble = fetchFromGitHub {
        owner = "nim-lang";
        repo = "nimble";
        rev = "v0.11.0";
        sha256 = "1n8qi10173cbwsai2y346zf3r14hk8qib2qfcfnlx9a8hibrh6rv";
      };
    
      enableParallelBuilding = true;
    
      NIX_LDFLAGS = [
        "-lcrypto"
        "-lpcre"
        "-lreadline"
        "-lgc"
        "-lsqlite3"
      ];
    
      nativeBuildInputs = [
        makeWrapper coreutils
      ];
    
      buildInputs = [
        openssl pcre readline boehmgc sfml sqlite
      ];
    
      phases = [ "unpackPhase" "buildPhase" "installPhase" ];
    
      buildPhase = ''
        # use $CC to trigger the linker since calling ld in build.sh causes an error
        LD=$CC
        # build.sh wants to write to $HOME/.cache
        HOME=$TMPDIR

        cp -rTs ${src-csources} csources
        chmod u+w -R csources

        mkdir dist
        cp -rT ${src-nimble} dist/nimble
        chmod u+w -R dist/nimble

        (cd csources; sh build.sh; )
        ./bin/nim c koch
        ./koch boot  -d:release \
                     -d:useGnuReadline \
                     ${lib.optionals (stdenv.isDarwin || stdenv.isLinux) "-d:nativeStacktrace"}
        ./koch tools -d:release
      '';
    
      installPhase = ''
        install -Dt $out/bin bin/* koch
        ./koch install $out
        mv $out/nim/bin/* $out/bin/ && rmdir $out/nim/bin
        mv $out/nim/*     $out/     && rmdir $out/nim
        wrapProgram $out/bin/nim \
          --suffix PATH : ${lib.makeBinPath [ stdenv.cc ]}
      '';
    };
  nim-versions = {
    "git"    = nim-git;
    "1.0.0"  = nim-common "1.0.0"  "1pg0lxahis8zfk6rdzdj281bahl8wglpjgngkc4vg1pc9p61fj03";
    "0.20.2" = nim-common "0.20.2" "0pibil10x0c181kw705phlwk8bn8dy5ghqd9h9fm6i9afrz5ryp1";
    "0.19.6" = nim-common "0.19.6" "0a9sgvb370iv4fwkqha8x4x02zngb505vlfn9x6l74lks9c0r7x0";
    "0.19.4" = nim-common "0.19.4" "0k59dhfsg5wnkc3nxg5a336pjd9jnfxabns63bl9n28iwdg16hgl";
    "0.19.0" = nim-common "0.19.0" "0biwvw1gividp5lkf0daq1wp9v6ms4xy6dkf5zj0sn9w4m3n76d1";
    "0.18.0" = nim-common "0.18.0" "1l1vdygbgs5fdh2ffdjapcp90p8f6cbsw4hivndgm3gh6pdlmis5";
    "0.17.0" = nim-common "0.17.0" "16vsmk4rqnkg9lc9h9jk62ps0x778cdqg6qrs3k6fv2g73cqvq9n";
    "0.16.0" = nim-common "0.16.0" "0rsibhkc5n548bn9yyb9ycrdgaph5kq84sfxc9gabjs7pqirh6cy";
  };
  nim-current = builtins.getAttr v nim-versions;
in
stdenv.mkDerivation {
  name = "db_sqlite_ex-shell";
  buildInputs = [ sqlite postgresql_11 ];
  nativeBuildInputs = [ nim-current ];
  LD_LIBRARY_PATH = ''${sqlite.out}/lib:${postgresql_11.lib}/lib'';
}
