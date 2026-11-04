"use client";

import { Moon } from "lucide-react";
import { useTheme } from "@/hooks/use-theme";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { toggleTheme } = useTheme();
  return <Button type="button" variant="ghost" size="sm" onClick={toggleTheme} aria-label="Đổi giao diện sáng hoặc tối"><Moon size={18} /><span className="hidden sm:inline">Giao diện</span></Button>;
}
