{ v ? "0.20.2" }:
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
      version = "0.20.2-git";
    
      src = fetchFromGitHub {
        owner = "nim-lang";
        repo = "Nim";
        rev = "f9600b7207e45573ee066ec7c9145df113ff5b99";
        sha256 = "1vx89j4rydw6gj9gcwxpih18kqaax9fcgfvxi7v9q554i6miwg55";
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
        rev = "v0.10.2";
        sha256 = "1l292d1z9a5wrc1i58znlpxbqvh69pr0qdv9zvhq29lr9vnkx1a2";
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
