"""Применяет правки к уже существующим файлам (безопасно запускать повторно)."""
import sys


def patch(path, old, new, marker):
    s = open(path, encoding="utf-8").read()
    if marker in s:
        print("уже применено:", path, "|", marker[:40])
        return
    if old not in s:
        sys.exit("НЕ НАЙДЕНО в %s: %s" % (path, old[:70]))
    open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
    print("применено:", path)


CONTENT_OLD = """                    case .home:
                        HomeScreen(palette: palette)
                    case .cases:
                        ComingSoon(title: "Кейсы", icon: "briefcase.fill", text: "Скоро здесь будут кейсы, как на сайте")
                    case .profile:
                        ProfileScreen(palette: palette)
                    }
                }
                .frame(maxHeight: .infinity)"""

CONTENT_NEW = """                    case .home:
                        HomeScreen(palette: palette).transition(.opacity)
                    case .cases:
                        CasesScreen().transition(.opacity)
                    case .profile:
                        ProfileScreen(palette: palette).transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeOut(duration: 0.18), value: tab)"""

patch("App/ContentView.swift", CONTENT_OLD, CONTENT_NEW, "CasesScreen()")

patch("App/VPNManager.swift",
      "                UINotificationFeedbackGenerator().notificationOccurred(.success)\n            }",
      "                UINotificationFeedbackGenerator().notificationOccurred(.success)\n                SoundEngine.shared.play(.connect)\n            }",
      "SoundEngine.shared.play(.connect)")

patch("App/VPNManager.swift",
      "            sessionStart = nil\n            traffic.stop()",
      "            sessionStart = nil\n            traffic.stop()\n            SoundEngine.shared.play(.disconnect)",
      "SoundEngine.shared.play(.disconnect)")

# окно выдачи приза: стабильная идентичность вместо пересоздания на каждый рендер
patch("App/Cases/CasesScreen.swift",
      "    @State private var manualReward: ManualReward?\n",
      "    @State private var manualBox: ManualBox?\n",
      "@State private var manualBox")
patch("App/Cases/CasesScreen.swift",
      "            manualReward = manual\n",
      "            manualBox = ManualBox(reward: manual)\n",
      "manualBox = ManualBox(reward: manual)")
patch("App/Cases/CasesScreen.swift",
      "        .sheet(item: Binding(get: { manualReward.map { ManualBox(reward: $0) } }, set: { if $0 == nil { manualReward = nil } })) { box in\n            ManualRewardSheet(reward: box.reward)\n        }\n",
      "        .sheet(item: $manualBox) { box in\n            ManualRewardSheet(reward: box.reward)\n        }\n",
      ".sheet(item: $manualBox)")

# блик дракона реже: 20 кадров/с вместо 30
_p = "App/SceneBackground.swift"
_t = open(_p, encoding="utf-8").read()
_o = "TimelineView(.animation(minimumInterval: 1.0 / 30.0))"
if _o in _t:
    open(_p, "w", encoding="utf-8").write(_t.replace(_o, "TimelineView(.animation(minimumInterval: 1.0 / 20.0))", 1))
    print("применено: SceneBackground")

print("APPLY OK")
