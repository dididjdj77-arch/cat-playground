import { failWithList, readText } from "./repo-spine-check.mjs";

const routeExpectations = [
  ["apps/expo/app/(tabs)/house.tsx", "/house"],
  ["apps/expo/app/(tabs)/diary.tsx", "/diary"],
  ["apps/expo/app/(tabs)/social.tsx", "/social"],
  ["apps/expo/app/(tabs)/settings.tsx", "/settings"],
  ["apps/web/app/c/page.tsx", "/c"],
  ["apps/web/app/c/[topicSlug]/page.tsx", "/c/{topicSlug}"],
  ["apps/web/app/c/[topicSlug]/[threadId]/page.tsx", "/c/{topicSlug}/{threadId}"],
  ["apps/web/app/p/page.tsx", "/p"],
  ["apps/web/app/p/[postId]/page.tsx", "/p/{postId}"],
  ["apps/web/app/search/page.tsx", "/search"]
];

const mismatchedRouteStubs = [];

for (const [relativePath, expectedRoute] of routeExpectations) {
  const source = readText(relativePath);
  if (!source.includes(expectedRoute)) {
    mismatchedRouteStubs.push(`${relativePath} missing ${expectedRoute}`);
  }
}

const failed = failWithList("route stubs are missing expected route strings", mismatchedRouteStubs);

if (failed) {
  process.exit(1);
}

console.log("PASS: repo:test");
