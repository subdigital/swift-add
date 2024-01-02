default:
	@just --list

build:
	swift build

test-all: build
	swift test | xcbeautify

# run the specified test
test TEST: build
	swift test --filter "{{TEST}}" | xcbeautify

# watch files and run the specified test
watch *ARGS:
	swift watch -s="just test {{ARGS}}"
