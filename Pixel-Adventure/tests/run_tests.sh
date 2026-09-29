#!/usr/bin/env bash
# Chạy các test headless (tests/test_*.gd, hoặc các file truyền vào) và chỉ coi là PASS
# khi output có dòng "ALL PASS". Godot thoát với mã 0 cả khi script test lỗi parse, và
# treo mãi nếu test crash trước khi gọi quit() — nên kiểm tra output và đặt timeout.
#
# Dùng (trong thư mục project Godot):  tests/run_tests.sh [tests/test_x.gd ...]
set -u
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
TIMEOUT=${TEST_TIMEOUT:-60}
cd "$(dirname "$0")/.."

"$GODOT" --headless --path . --import >/dev/null 2>&1

files=("$@")
[ ${#files[@]} -eq 0 ] && files=(tests/test_*.gd)

failed=0
for f in "${files[@]}"; do
	out=$(perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" "$GODOT" --headless --path . --script "res://$f" 2>&1)
	if printf '%s\n' "$out" | grep -q '^ALL PASS$'; then
		echo "ok   $f"
	else
		failed=$((failed + 1))
		echo "FAIL $f"
		printf '%s\n' "$out" | grep -E 'FAIL|ERROR|FAILED' | head -20
	fi
done

if [ "$failed" -eq 0 ]; then
	echo "ALL TEST FILES PASS (${#files[@]})"
else
	echo "$failed TEST FILE(S) FAILED"
	exit 1
fi
