class_name ResultHighlights
extends RefCounted
## Human-facing summaries of already-collected match statistics, never inferred awards.


static func lines(rows: Array[Dictionary], local_slots: Array[int]) -> String:
	var out: Array[String] = []
	for slot: int in local_slots:
		for row: Dictionary in rows:
			if int(row.get("slot", -1)) != slot:
				continue
			out.append("%s · 링아웃 %d회  /  아이템 %d회  /  필살기 적중 %d회" % [
				PlayerStyle.label(slot), int(row.get("ringouts_scored", 0)),
				int(row.get("items_used", 0)), int(row.get("special_hits", 0))])
	return "\n".join(out)
