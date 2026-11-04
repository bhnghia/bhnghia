"use client";

import { useEffect } from "react";

export type Theme = "light" | "dark";

export function useTheme() {
  useEffect(() => {
    const saved = localStorage.getItem("vett-theme");
    const next = saved === "light" || saved === "dark" ? saved : "light";
    document.documentElement.dataset.theme = next;
  }, []);

  function toggleTheme() {
    const next: Theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    localStorage.setItem("vett-theme", next);
  }

  return { toggleTheme };
}
