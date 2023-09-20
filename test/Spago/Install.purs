module Test.Spago.Install where

import Test.Prelude

import Data.Map as Map
import Registry.Version as Version
import Spago.Command.Init as Init
import Spago.Core.Config (Dependencies(..))
import Spago.Core.Config as Config
import Spago.FS as FS
import Test.Spec (Spec)
import Test.Spec as Spec

spec :: Spec Unit
spec = Spec.around withTempDir do
  Spec.describe "install" do

    Spec.it "warns that config was not changed when trying to install a package already present in project dependencies" \{ spago, fixture } -> do
      spago [ "init", "--name", "7368613235362d50744f44764f717435586c685938735a5154" ] >>= shouldBeSuccess
      spago [ "install" ] >>= shouldBeSuccess
      spago [ "fetch", "effect" ] >>= shouldBeSuccessErr (fixture "spago-install-existing-dep-stderr.txt")

    -- TODO: spago will currently crash if you try to have a purescript prefix. I guess we should fix this to at least not crash?
    -- Spec.it "Spago should strip 'purescript-' prefix and give warning if package without prefix is present in package set" \{ spago, fixture } -> do
    --   spago [ "init" ] >>= shouldBeSuccess
    --   spago [ "install", "safe-coerce" ] >>= shouldBeSuccess
    --   spago [ "install", "purescript-newtype" ] >>= shouldBeSuccessErr (fixture "spago-install-purescript-prefix-stderr.txt")
    --   -- dep added without "purescript-" prefix
    --   checkFixture "spago.yaml" (fixture "spago-strips-purescript.yaml")

    Spec.it "adds dependencies to the config file" \{ spago, fixture } -> do
      spago [ "init", "--name", "aaa", "--package-set", "29.3.0" ] >>= shouldBeSuccess
      spago [ "install", "foreign" ] >>= shouldBeSuccess
      checkFixture "spago.yaml" (fixture "spago-install-success.yaml")

    Spec.it "can't add dependencies that are not in the package set" \{ spago, fixture } -> do
      spago [ "init", "--name", "aaaa", "--package-set", "29.3.0" ] >>= shouldBeSuccess
      spago [ "install", "foo", "bar" ] >>= shouldBeFailureErr (fixture "missing-dependencies.txt")
      checkFixture "spago.yaml" (fixture "spago-install-failure.yaml")

    Spec.it "does not allow circular dependencies" \{ spago, fixture } -> do
      spago [ "init" ] >>= shouldBeSuccess
      let
        conf = Init.defaultConfig
          (mkPackageName "bbb")
          (Just $ unsafeFromRight $ Version.parse "0.0.1")
          "Test.Main"
      FS.writeYamlFile Config.configCodec "spago.yaml"
        ( conf
            { workspace = conf.workspace # map
                ( _
                    { extra_packages = Just $ Map.fromFoldable
                        [ Tuple (mkPackageName "a") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
                            { git: "https://github.com/purescript/spago.git"
                            , ref: "master"
                            , subdir: Nothing
                            , dependencies: Just $ Dependencies $ Map.singleton (mkPackageName "b") Nothing
                            }
                        , Tuple (mkPackageName "b") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
                            { git: "https://github.com/purescript/spago.git"
                            , ref: "master"
                            , subdir: Nothing
                            , dependencies: Just $ Dependencies $ Map.singleton (mkPackageName "a") Nothing
                            }
                        ]
                    }
                )
            }
        )
      spago [ "install", "a", "b" ] >>= shouldBeFailureErr (fixture "circular-dependencies.txt")

    Spec.it "installs a package in the set from a commit hash" \{ spago } -> do
      spago [ "init" ] >>= shouldBeSuccess
      -- The commit for `either` is for the `v6.1.0` release
      let
        conf = Init.defaultConfig
          (mkPackageName "eee")
          (Just $ unsafeFromRight $ Version.parse "0.0.1")
          "Test.Main"
      FS.writeYamlFile Config.configCodec "spago.yaml"
        ( conf
            { workspace = conf.workspace # map
                ( _
                    { extra_packages = Just $ Map.fromFoldable
                        [ Tuple (mkPackageName "either") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
                            { git: "https://github.com/purescript/purescript-either.git"
                            , ref: "af655a04ed2fd694b6688af39ee20d7907ad0763"
                            , subdir: Nothing
                            , dependencies: Just $ Dependencies $ Map.fromFoldable
                                [ mkPackageName "control" /\ Nothing
                                , mkPackageName "invariant" /\ Nothing
                                , mkPackageName "maybe" /\ Nothing
                                , mkPackageName "prelude" /\ Nothing
                                ]
                            }
                        ]
                    }
                )
            }
        )
      spago [ "install", "either" ] >>= shouldBeSuccess

    -- TODO: this is broken at the moment
    -- Spec.it "installs a package version by branch name with / in it" \{ spago, fixture } -> do
    --   spago [ "init" ] >>= shouldBeSuccess
    --   let
    --     conf = Init.defaultConfig
    --       (mkPackageName "ddd")
    --       (Just $ unsafeFromRight $ Version.parse "0.0.1")
    --       "Test.Main"
    --   FS.writeYamlFile Config.configCodec "spago.yaml"
    --     ( conf
    --         { workspace = conf.workspace # map
    --             ( _
    --                 { extra_packages = Just $ Map.fromFoldable
    --                     [ Tuple (mkPackageName "nonexistent-package") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
    --                         { git: "https://github.com/spacchetti/purescript-metadata.git"
    --                         , ref: "spago-test/branch-with-slash"
    --                         , subdir: Nothing
    --                         , dependencies: Just $ Dependencies $ Map.singleton (mkPackageName "prelude") Nothing
    --                         }
    --                     ]
    --                 }
    --             )
    --         }
    --     )
    --   spago [ "install", "nonexistent-package" ] >>= shouldBeSuccessErr (fixture "installs-with-slash.txt")

    Spec.it "installs a package not in the set from a commit hash" \{ spago } -> do
      spago [ "init" ] >>= shouldBeSuccess
      let
        conf = Init.defaultConfig
          (mkPackageName "eee")
          (Just $ unsafeFromRight $ Version.parse "0.0.1")
          "Test.Main"
      FS.writeYamlFile Config.configCodec "spago.yaml"
        ( conf
            { workspace = conf.workspace # map
                ( _
                    { extra_packages = Just $ Map.fromFoldable
                        [ Tuple (mkPackageName "spago") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
                            { git: "https://github.com/purescript/spago.git"
                            , ref: "cbdbbf8f8771a7e43f04b18cdefffbcb0f03a990"
                            , subdir: Nothing
                            , dependencies: Just $ Dependencies $ Map.singleton (mkPackageName "prelude") Nothing
                            }
                        ]
                    }
                )
            }
        )
      spago [ "install", "spago" ] >>= shouldBeSuccess

    Spec.it "can't install a package from a not-existing commit hash" \{ spago } -> do
      spago [ "init" ] >>= shouldBeSuccess
      let
        conf = Init.defaultConfig
          (mkPackageName "eee")
          (Just $ unsafeFromRight $ Version.parse "0.0.1")
          "Test.Main"
      FS.writeYamlFile Config.configCodec "spago.yaml"
        ( conf
            { workspace = conf.workspace # map
                ( _
                    { extra_packages = Just $ Map.fromFoldable
                        [ Tuple (mkPackageName "either") $ Config.ExtraRemotePackage $ Config.RemoteGitPackage
                            { git: "https://github.com/purescript/spago.git"
                            , ref: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                            , subdir: Nothing
                            , dependencies: Just $ Dependencies $ Map.singleton (mkPackageName "prelude") Nothing
                            }
                        ]
                    }
                )
            }
        )
      spago [ "install", "spago" ] >>= shouldBeFailure

    Spec.it "can update dependencies in a sub-package" \{ spago, fixture } -> do
      spago [ "init" ] >>= shouldBeSuccess
      FS.mkdirp "subpackage/src"
      FS.mkdirp "subpackage/test"
      FS.writeTextFile "subpackage/src/Main.purs" (Init.srcMainTemplate "Subpackage.Main")
      FS.writeTextFile "subpackage/test/Main.purs" (Init.testMainTemplate "Subpackage.Test.Main")
      FS.writeYamlFile Config.configCodec "subpackage/spago.yaml"
        ( Init.defaultConfig
            (mkPackageName "subpackage")
            Nothing
            "Subpackage.Test.Main"
        )
      spago [ "install", "-p", "subpackage", "either" ] >>= shouldBeSuccess
      checkFixture "subpackage/spago.yaml" (fixture "spago-subpackage-install-success.yaml")

    Spec.it "adds a hash to the package set when importing it from a URL" \{ spago, fixture } -> do
      spago [ "init" ] >>= shouldBeSuccess
      let
        conf = Init.defaultConfig
          (mkPackageName "aaa")
          (Just $ unsafeFromRight $ Version.parse "0.0.1")
          "Test.Main"
      FS.writeYamlFile Config.configCodec "spago.yaml"
        ( conf
            { workspace = conf.workspace # map
                ( _
                    { package_set = Just
                        ( Config.SetFromUrl
                            { hash: Nothing
                            , url: "https://raw.githubusercontent.com/purescript/registry/main/package-sets/29.3.0.json"
                            }
                        )
                    }
                )
            }
        )
      spago [ "install" ] >>= shouldBeSuccess
      checkFixture "spago.yaml" (fixture "spago-with-hash.yaml")
