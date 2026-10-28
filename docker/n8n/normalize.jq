# Normalize one n8n workflow for the repo: keeps the workflow definition,
# drops credential IDs, instance metadata, pinData and staticData.
# Use with `jq -S` so key order is stable.
{
  name,
  description: (.description // ""),
  nodes: [.nodes[] | if .credentials then .credentials |= map_values({name}) else . end],
  connections,
  settings
}
+ (if ((.nodeGroups // []) | length) > 0 then {nodeGroups} else {} end)
+ {active: false, tags: []}
