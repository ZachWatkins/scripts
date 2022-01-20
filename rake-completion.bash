# rake-completion.bash
#
# Copyright (c) 2022 konsolebox
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [[ BASH_VERSINFO -ge 5 ]]; then
	declare -gA _RAKE_COMP_OPT_CACHE=()
	declare -gA _RAKE_COMP_TASK_CACHE=()
	declare -gA _RAKE_COMP_TASK_CACHE_TS=()
	_RAKE_COMP_USE_STATIC_OPTS=${_RAKE_COMP_USE_STATIC_OPTS-false}
	_RAKE_COMP_CACHE_TASKS=${_RAKE_COMP_CACHE_TASKS-true}
	_RAKE_PATH=

	if false; then
		function _rake_comp_log_debug {
			logger -t rake-completion -p debug -- "${FUNCNAME[1]-}${FUNCNAME[1]+: }$1"
		}
	fi

	function _rake_comp_get_all_opts {
		if [[ ${_RAKE_COMP_USE_STATIC_OPTS} == true ]]; then
			# From rake 13.0.6
			__="-A -B -C -D -E -G -H -I -N -P -R -T -V -W -X -e -f -g -h -j -m -n -p -q -r -s -t -v --all --backtrace --build-all --comments --describe --directory --dry-run --execute --execute-continue --execute-print --help --jobs --job-stats --libdir --multitask --nosearch --nosystem --no-deprecation-warnings --no-search --no-system --prereqs --quiet --rakefile --rakelib --rakelibdir --require --rules --silent --suppress-backtrace --system --tasks --trace --verbose --version --where"
		else
			__=${_RAKE_COMP_OPT_CACHE["all_opts|${_RAKE_PATH}"]-}

			if [[ -z $__ ]]; then
				__=$(
					shopt -so pipefail

					"${_RAKE_PATH}" --help 2>&1 | awk -F '[ =,]+' '
						p {
							for (i = 2; i <= NF; ++i) {
								if ($i ~ /^-/) {
									print $i
								} else {
									break
								}
							}
						}
						/Opt/ { p = 1 }
					'
				) || return 1

				_RAKE_COMP_OPT_CACHE["all_opts|${_RAKE_PATH}"]=$__
			fi
		fi

		return 0
	}

	function _rake_comp_get_opts_with_arg_expr {
		if [[ ${_RAKE_COMP_USE_STATIC_OPTS} == true ]]; then
			# From rake 13.0.6
			__="--backtrace|--job-stats|--suppress-backtrace|-C|--directory|-D|--describe|-e|--execute|-E|--execute-continue|-f|--rakefile|-I|--libdir|-j|--jobs|-p|--execute-print|-r|--require|-R|--rakelibdir|-t|--trace|-T|--tasks|-W|--where"
		else
			__=${_RAKE_COMP_OPT_CACHE["opts_with_arg_expr|${_RAKE_PATH}"]-}

			if [[ -z $__ ]]; then
				__=$(
					shopt -so pipefail

					"${_RAKE_PATH}" --help 2>&1 | awk -F '[ =,]+' -v ORS='|' '
						p {
							delete t
							for (i = 2; i <= NF; ++i)
								if ($i ~ /^-/) {
									t[i] = $i
								} else {
									if ($i ~ /^\[?[A-Z]+\]?$/)
										for (j in t)
											print t[j]
									break
								}
						}
						/Opt/ { p = 1 }
					'
				) || return 1

				__=${__%'|'}
				_RAKE_COMP_OPT_CACHE["opts_with_arg_expr|${_RAKE_PATH}"]=$__
			fi
		fi

		return 0
	}

	function _rake_comp_target_likely_specified {
		local opts_with_arg_expr= i __
		_rake_comp_get_opts_with_arg_expr && opts_with_arg_expr=$__

		for (( i = 1; i < ${#COMP_WORDS[@]}; ++i )); do
			case ${COMP_WORDS[i]} in
			--)
				break
				;;
			+([a-z0-9_])?(:)*)
				[[ i -ne COMP_CWORD ]] && return 0
				;;
			${opts_with_arg_expr})
				(( ++i ))
				;;
			esac
		done

		return 1
	}

	function _rake_comp_get_specified_rakefile {
		local opts_with_arg_expr=
		_rake_comp_get_opts_with_arg_expr && opts_with_arg_expr=$__
		set -- "${COMP_WORDS[@]}"
		__=

		while shift; [[ $# -gt 0 && $1 != -- ]]; do
			case $1 in
			-f|--rakefile)
				__=$2
				shift
				;;
			-f*|--rakefile=*)
				__=${1#@(-f|--rakefile=)}
				;;
			${opts_with_arg_expr})
				shift
				;;
			esac
		done

		[[ $__ && -f $__ ]]
	}

	function _rake_comp_get_default_rakefile {
		local IFS=/

		if [[ $- == *f* ]]; then
			set -- ${PWD}
		else
			set -f
			set -- ${PWD}
			set +f
		fi

		while [[ $# -gt 0 ]]; do
			for __ in rakefile Rakefile rakefile.rb Rakefile.rb; do
				__="$*/$__"
				[[ -f $__ ]] && return 0
			done

			set -- "${@:1:$# - 1}"
		done

		__=
		return 1
	}

	function _rake_comp_generate_filename_replies {
		local one_final_result=false temp i gen_type=${2-f}
		readarray -t COMPREPLY < <(compgen -"${gen_type}" -- "$1")

		while [[ ${#COMPREPLY[@]} -eq 1 && -d ${COMPREPLY} && -x ${COMPREPLY} ]]; do
			readarray -t temp < <(cd "${COMPREPLY}" &>/dev/null && compgen -"${gen_type}")
			[[ ${#temp[@]} -eq 0 ]] && break
			COMPREPLY=("${temp[@]/#/"${COMPREPLY%/}/"}")
		done

		[[ ${#COMPREPLY[@]} -eq 1 ]] && test -"${gen_type}" "${COMPREPLY}" && one_final_result=true

		for i in "${!COMPREPLY[@]}"; do
			[[ -d ${COMPREPLY[i]} ]] && COMPREPLY[i]=${COMPREPLY[i]%%+(/)}/
			printf -v "COMPREPLY[$i]" %q "${COMPREPLY[i]}"
		done

		[[ ${one_final_result} == true ]]
	}

	function rake_comp_get_tasks {
		local ts

		if [[ ${_RAKE_COMP_CACHE_TASKS} == true ]]; then
			ts=$(date +%s -r "$1") || ts=
			__=${_RAKE_COMP_TASK_CACHE[$1]-}
			[[ $__ && ${ts} && ${_RAKE_COMP_TASK_CACHE_TS[$1]-} == ${ts} ]] && return 0
		fi

		__=$("${_RAKE_PATH}" -f "$1" --tasks 2>&1 | awk '$1 == "rake" && / # / { print $2 }')

		if [[ $__ && ${_RAKE_COMP_CACHE_TASKS} == true && ${ts} ]]; then
			_RAKE_COMP_TASK_CACHE[$1]=$__
			_RAKE_COMP_TASK_CACHE_TS[$1]=${ts}
		fi

		[[ $__ ]]
	}

	function _rake_comp_past_double_dash {
		local i

		for (( i = 1; i < COMP_CWORD; ++i )); do
			[[ ${COMP_WORDS[i]} == -- ]] && return 0
		done

		return 1
	}

	function _rake_comp_try_get_opt_with_arg {
		local -n __opt=$1 __arg=$2 __prefix=$3; shift 3
		_rake_comp_get_opts_with_arg_expr

		if [[ ${2-} == @($__) ]]; then
			__opt=$2 __arg=$1 __prefix=
		elif [[ $1 == @($__) ]]; then
			__opt=$1 __arg= __prefix=$1
		elif [[ $1 == --* && $1 == @($__)=* ]]; then
			__arg=${1#*=} __prefix=${1:0:(${#1} - ${#__arg})} __opt=${__prefix%=}
		elif [[ $1 != --* && $1 == @($__)* ]]; then
			__arg=${1#*=} __prefix=${1:0:(${#1} - ${#__arg})} __opt=$__prefix
		else
			return 1
		fi

		return 0
	}

	function _rake_comp {
		local dont_add_space=false opt arg prefix i __
		_RAKE_PATH=$(type -p rake) && [[ ${_RAKE_PATH} ]] || return
		COMPREPLY=()

		if _rake_comp_past_double_dash; then
			_rake_comp_generate_filename_replies "$2" || dont_add_space=true
		elif _rake_comp_try_get_opt_with_arg opt arg prefix "${@:2}"; then
			case ${opt} in
			-C|--directory|-I|--libdir|-R|--rakelibdir)
				_rake_comp_generate_filename_replies "${arg}" d || dont_add_space=true
				;;
			-f|--rakefile)
				_rake_comp_generate_filename_replies "${arg}" || dont_add_space=true
				;;
			esac

			if [[ ${prefix} ]]; then
				for i in "${!COMPREPLY[@]}"; do
					COMPREPLY[i]=${prefix}${COMPREPLY[i]}
				done
			fi
		elif [[ $2 == -* ]]; then
			_rake_comp_get_all_opts || return
			readarray -t COMPREPLY < <(compgen -W "$__" -- "$2")
		elif ! _rake_comp_target_likely_specified && { _rake_comp_get_specified_rakefile || \
				_rake_comp_get_default_rakefile; }; then
			rake_comp_get_tasks "$__" || return
			readarray -t COMPREPLY < <(compgen -W "$__" -- "$2")
		fi

		[[ ${#COMPREPLY[@]} -eq 1 && ${dont_add_space} == false ]] && COMPREPLY+=' '
	}

	# Excluding ':' from COMP_WORDBREAKS is necessary so tasks that are named
	# with a colon can be recognized, but it conflicts with other completion
	# implementations that require it like git's contrib/git-completion.bash.
	#
	# Comment out the following line if the conflict needs to be avoided.
	#
	COMP_WORDBREAKS=${COMP_WORDBREAKS//:}

	# Removing '=' is also necessary since the equal sign still becomes stored
	# as a separate argument in COMP_WORDS.  Besides that, the equal sign can
	# also be a part of the filename and even though COMP_WORDS can be
	# recomposed using `compgen -W`, telling bash how the token should be
	# completed itself would require an ugly workaround since the token is
	# already split.  Perhaps the replies can be trimmed out so they don't
	# include the partial strings which aren't originally part of the token
	# being completed, but they would look terrible when displayed.  So
	# generally the added hack isn't worth it.
	#
	COMP_WORDBREAKS=${COMP_WORDBREAKS//=}

	complete -F _rake_comp -o nospace rake
fi
