import fs from "node:fs";

const PATH = "docs/DECISIONS.md";
const text = fs.readFileSync(PATH, "utf8");

// 1) D-### 헤딩 추출
const re = /^##\s+D-(\d{3})\b/gm;
const nums = [];
let m;
while ((m = re.exec(text)) !== null) nums.push(Number(m[1]));

// 2) 최소 검증
if (nums.length === 0) {
  console.error(`[FAIL] ${PATH}: No "## D-###" headings found.`);
  process.exit(1);
}

// 중복 체크
const seen = new Set();
const dupes = new Set();
for (const n of nums) {
  if (seen.has(n)) dupes.add(n);
  seen.add(n);
}
if (dupes.size > 0) {
  console.error(`[FAIL] ${PATH}: Duplicate decision numbers: ${[...dupes].map(n => `D-${String(n).padStart(3,"0")}`).join(", ")}`);
  process.exit(1);
}

// 증가(정렬) 체크 (문서 내에서 번호가 역행하면 FAIL)
for (let i = 1; i < nums.length; i++) {
  if (nums[i] <= nums[i - 1]) {
    console.error(
      `[FAIL] ${PATH}: Non-increasing decision order at index ${i}: ` +
      `D-${String(nums[i - 1]).padStart(3,"0")} -> D-${String(nums[i]).padStart(3,"0")}`
    );
    process.exit(1);
  }
}

console.log(`[OK] ${PATH}: ${nums.length} decisions. Last = D-${String(nums[nums.length-1]).padStart(3,"0")}`);
