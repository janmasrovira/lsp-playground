disableParallel := ''
# set to non-empty string to disable optimized build
#
# e.g:
#   just disableOptimized=yes install
disableOptimized := ''

# set to non-empty string to enable command debugging
enableDebug := ''

# set to non-empty string to enable pedantic mode
pedantic := ''

# set to number of parallel jobs
numParallelJobs := ''

# the command used to run stack
stack := "stack"

# the command used to run ormolu
ormolu := "ormolu"

# The CC argument to the runtime Makefile
runtimeCcArg := ''

# The LIBTOOL argument to the runtime Makefile
runtimeLibtoolArg := ''

# The flags used in the runtime make commands
runtimeCcFlag := if runtimeCcArg == '' { '' } else { "CC=" + runtimeCcArg }
runtimeLibtoolFlag := if runtimeLibtoolArg == '' { '' } else { "LIBTOOL=" + runtimeLibtoolArg }
runtimeArgs := trim(runtimeCcFlag + ' ' + runtimeLibtoolFlag)

# flags used in the stack command
stackOptFlag := (if disableOptimized == '' { '' } else { '--fast' }) + ' ' + (if pedantic == '' { '' } else { '--pedantic' })
# The ghc `-j` flag defaults to number of cpus when no argument is passed
stackGhcParallelFlag := if disableParallel == '' { "--ghc-options=-j" + numParallelJobs } else { '' }
# The stack `-j` options requires an argument
stackParallelFlagJobs := if numParallelJobs == '' { num_cpus() } else { numParallelJobs }
stackParallelFlag := if disableParallel == '' { '-j' + stackParallelFlagJobs } else { '' }
stackArgs := stackOptFlag + ' ' + stackParallelFlag + ' ' + stackGhcParallelFlag

# flags used in the stack test command
testArgs := "--hide-successes"
rtsFlag := if disableParallel == '' { '+RTS -N' + numParallelJobs + ' -RTS' } else { '' }

# flag used to enable tracing of bash commands
bashDebugArg := if enableDebug == '' { '' } else { 'x' }

[private]
default:
    @just --list

@_ormoluCmd filesCmd mode:
    {{ trim(filesCmd) }} \
     | xargs -r {{ ormolu }} --mode {{ mode }}

# Formats all Haskell files in the project. `format changed` formats only changed files. `format FILES` formats individual files.
format *opts:
    #!/usr/bin/env bash
    set -euo{{ bashDebugArg }} pipefail

    if [ ! -e "lsp-playground.cabal" ]; then
        echo "Error: lsp-playground.cabal does not exist. Please, run 'just install' or 'stack setup' first"
        exit 1
    fi

    opts='{{ trim(opts) }}'

    case $opts in
        "")
            just _ormoluCmd "git ls-files '*.hs'" inplace
            ;;
        changed)
            just _ormoluCmd \
              "(git --no-pager diff --name-only --diff-filter=AM && git --no-pager diff --cached --name-only --diff-filter=AM) | grep '\\.hs\$'" \
              inplace
            ;;
        check)
            just _ormoluCmd "git ls-files '*.hs'" check
            ;;
        *)
            just _ormoluCmd "echo {{ opts }}"
            ;;
    esac

# Run the tests in the project. Use the filter arg to set a Tasty pattern.
[no-exit-message]
test *filter:
    #!/usr/bin/env bash
    set -euo{{ bashDebugArg }} pipefail
    filter='{{ trim(filter) }}'
    if [ -n "$filter" ]; then
      filter="-p \"$filter\""
    fi
    set -x
    {{ stack }} test {{ stackArgs }} --ta "{{ testArgs }} {{ rtsFlag }} $filter"

# Compile-time configuration
configure:
    {{ runtimeCcFlag }} config/configure.sh

# Build the project. `build runtime` builds only the runtime.
[no-exit-message]
build *opts:
    #!/usr/bin/env bash
    set -euo{{ bashDebugArg }} pipefail
    opts='{{ trim(opts) }}'

    case $opts in
        runtime)
            just runtimeCcArg="{{ runtimeCcArg }}" runtimeArgs="{{ runtimeArgs }}" _buildRuntime
            ;;
        *)
            just runtimeCcArg="{{ runtimeCcArg }}" runtimeArgs="{{ runtimeArgs }}" _buildRuntime
            set -x
            {{ stack }} build {{ stackArgs }}
            ;;
    esac

[no-exit-message]
install:
    {{ stack }} install {{ stackArgs }}

clean:
   {{ stack }} clean --full
