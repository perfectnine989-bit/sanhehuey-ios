import SwiftUI

struct HistoryRow: Identifiable {
    let id = UUID()
    let prize: String
    let caseId: String
    let date: String
}

struct Referral {
    var exists: Bool
    var url: String
    var count: Int
    var casesG: Int
    var casesTopG: Int
    var nextTopG: Int
}

@MainActor
final class CasesStore: ObservableObject {
    @Published var defs: [CaseDef] = [CaseDef.free]
    @Published var history: [HistoryRow] = []
    @Published var referral: Referral?

    func load() async {
        guard let r = try? await SiteAPI.shared.json("/api/cases"), r.status == 200 else { return }
        var list: [CaseDef] = []
        for id in CaseThemes.order {
            if id == "free" {
                list.append(CaseDef.free)
            } else if let d = r.obj[id] as? [String: Any] {
                list.append(CaseDef(id: id, json: d))
            }
        }
        for (key, value) in r.obj.sorted(by: { $0.key < $1.key }) where !CaseThemes.order.contains(key) {
            if let d = value as? [String: Any], d["prizes"] != nil {
                list.append(CaseDef(id: key, json: d))
            }
        }
        defs = list
    }

    func loadHistory() async {
        guard let r = try? await SiteAPI.shared.json("/api/cases/history"), r.status == 200 else { return }
        let rows = r.obj["history"] as? [[String: Any]] ?? []
        history = rows.prefix(8).map {
            HistoryRow(prize: jStr($0["prize"]), caseId: jStr($0["case"]), date: jStr($0["date"]))
        }
    }

    func loadReferral() async {
        guard let r = try? await SiteAPI.shared.json("/api/referral"), r.status == 200 else { return }
        let d = r.obj
        referral = Referral(
            exists: jBool(d["exists"]),
            url: jStr(d["ref_url"]),
            count: jInt(d["referral_count"]),
            casesG: jInt(d["cases_g"]),
            casesTopG: jInt(d["cases_topg"]),
            nextTopG: jInt(d["next_topg"])
        )
    }
}
