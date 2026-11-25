#!/bin/bash
# 把仓库 book/ 各子文件夹里的 txt 与 aibook 拷进 iOS 包，供安装后作为初始书籍。
set -euo pipefail

src="${SRCROOT}/book"
dest="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/SeedBooks"

rm -rf "$dest"
mkdir -p "$dest"

if [[ ! -d "$src" ]]; then
  echo "note: book folder missing, SeedBooks left empty"
  exit 0
fi

copied=0
while IFS= read -r -d '' file; do
  rel="${file#"$src"/}"
  mkdir -p "$dest/$(dirname "$rel")"
  cp "$file" "$dest/$rel"
  copied=$((copied + 1))
done < <(find "$src" -mindepth 2 -type f \( -iname '*.txt' -o -iname '*.aibook' \) ! -name '.*' -print0)

echo "copied ${copied} seed books into ${dest}"

manual_dest="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
for manual in "${SRCROOT}"/Sources/AIBook/Resources/功能说明书*.md; do
  if [[ -f "$manual" ]]; then
    cp "$manual" "$manual_dest/"
  fi
done
echo "copied user manuals into ${manual_dest}"
