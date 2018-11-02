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
  nim-git =
    stdenv.mkDerivation rec {
      name = "nim-${version}";
      version = "0.19.0-git";
    
      src = fetchFromGitHub {
        owner = "nim-lang";
        repo = "Nim";
        rev = "2bc016b1720da62e6fc6016e38705cde3b797728";
        sha256 = "0a310y54pcv4gnlb6nh81dxgzzzd8ln3hdb0y1car7sh1ld26pdc";
      };
      src-csources = fetchFromGitHub {
        owner = "nim-lang";
        repo = "csources";
        rev = "v0.19.0";
        sha256 = "00mzzhnp1myjbn3rw8qfnz593phn8vmcffw2lf1r2ncppck5jbpj";
      };
      src-nimble = fetchFromGitHub {
        owner = "nim-lang";
        repo = "nimble";
        rev = "v0.9.0";
        sha256 = "16aiav360p3fj7r044cb2hq59szx7igrx60r782dfr4cfhyc1p4s";
      };
    
      enableParallelBuilding = true;
    
      NIX_LDFLAGS = [
        "-lcrypto"
        "-lpcre"
        "-lreadline"
        "-lgc"
      ];
    
      nativeBuildInputs = [
        makeWrapper coreutils
      ];
    
      buildInputs = [
        openssl pcre readline boehmgc sfml
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
