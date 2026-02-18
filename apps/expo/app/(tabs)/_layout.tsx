import { Slot } from "expo-router";

export const APP_TAB_ROUTES = ["house", "diary", "social", "settings"] as const;

export default function AppTabsLayout() {
  return <Slot />;
}
