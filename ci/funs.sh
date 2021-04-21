# Utilities used in CI pipelines and tooling to avoid duplication.
# Avoid top-level statements.
# Prefer nim scripts whenever possible.

echo_run () {
  # echo's a command before running it, which helps understanding logs
  echo ""
  echo "$@"
  "$@"
}

nimGetLastCommit() {
  git log --no-merges -1 --pretty=format:"%s"
}

nimIsCiSkip(){
  # D20210329T004830:here refs https://github.com/microsoft/azure-pipelines-agent/issues/2944
  # `--no-merges` is needed to avoid merge commits which occur for PR's.
  # $(Build.SourceVersionMessage) is not helpful
  # nor is `github.event.head_commit.message` for github actions.
  # Note: `[skip ci]` is now handled automatically for github actions, see https://github.blog/changelog/2021-02-08-github-actions-skip-pull-request-and-push-workflows-with-skip-ci/
  commitMsg=$(nimGetLastCommit)
  echo commitMsg: "$commitMsg"
  if [[ $commitMsg == *"[skip ci]"* ]]; then
    echo "skipci: true"
    return 0
  else
    echo "skipci: false"
    return 1
  fi
}

nimDefineVars(){
  nim_csources=bin/nim_csources_v1
  nim_csourcesDir=csources
  nim_csourcesUrl=https://github.com/nim-lang/csources_v1.git
  nim_csourcesHash=a8a5241f9475099c823cfe1a5e0ca4022ac201ff
}

_build_nim_csources_via_script(){
  # avoid changing dir in case of failure
  (
    echo_run cd $nim_csourcesDir
    echo_run sh build.sh "$@"
  )
}

_nimBuildCsourcesIfNeeded(){
  if [ $# -ne 0 ]; then
    # some args were passed (e.g.: `--cpu i386`), need to call build.sh
    _build_nim_csources_via_script "$@"
  else
    # no args, use multiple Make jobs (5X faster on 16 cores: 10s instead of 50s)
    makeX=make
    # uname values: https://en.wikipedia.org/wiki/Uname
    unamestr=$(uname)
    if [ "$unamestr" = 'FreeBSD' ]; then
      makeX=gmake
      # nCPU=$(sysctl -n hw.ncpu) ?
    fi
    if [ "$unamestr" = 'OpenBSD' ]; then
      makeX=gmake
      # nCPU=$(sysctl -n hw.ncpuonline) ?
    fi

    nCPU=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || 1)

  # on travis:
  # - make -C csources -j 2 LD=$CC ucpu=$CPU
  # -  . ci/funs.sh && LD=$CC ucpu=$CPU nimBuildCsourcesIfNeeded

    which $makeX && echo_run $makeX -C $nim_csourcesDir -j $((nCPU + 2)) -l $nCPU || _build_nim_csources_via_script
  fi
  # keep $nim_csources in case needed to investigate bootstrap issues
  # without having to rebuild from csources
  echo_run cp bin/nim $nim_csources
}

nimBuildCsourcesIfNeeded(){
  # goal: allow cachine each tagged version independently
  # to avoid rebuilding csources, so that tools
  # like `git bisect` can grab a cached past version
  # of bin/nim_csources without rebuilding.
  nimDefineVars
  if test -f "$nim_csources"; then
    echo "$nim_csources exists."
  else
    if test -d "$nim_csourcesDir"; then
      echo "$nim_csourcesDir exists."
    else
      # depth 1: adjust as needed in case useful for `git bisect`
      echo_run git clone -q --depth 1 $nim_csourcesUrl "$nim_csourcesDir"
      echo_run git -C "$nim_csourcesDir" checkout $nim_csourcesHash
    fi
    _nimBuildCsourcesIfNeeded "$@"
  fi

  echo_run cp $nim_csources bin/nim
  echo_run $nim_csources -v

  # build.sh:
  # sh build.sh
}
