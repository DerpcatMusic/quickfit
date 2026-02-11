export type LeadTimeSurgeRule = {
  maxHoursBeforeStart: number;
  boostPercent: number;
};

const MIN_HOURS = 0.25;
const MAX_HOURS = 168;
const MIN_BOOST = 0;
const MAX_BOOST = 200;

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

export function normalizeLeadTimeSurgeRules(
  rules: LeadTimeSurgeRule[] | undefined,
): LeadTimeSurgeRule[] {
  if (!rules || rules.length === 0) return [];

  const normalized = rules
    .map((rule) => ({
      maxHoursBeforeStart: clamp(rule.maxHoursBeforeStart, MIN_HOURS, MAX_HOURS),
      boostPercent: clamp(rule.boostPercent, MIN_BOOST, MAX_BOOST),
    }))
    .sort((a, b) => a.maxHoursBeforeStart - b.maxHoursBeforeStart);

  const deduped: LeadTimeSurgeRule[] = [];
  for (const rule of normalized) {
    const hasSameWindow = deduped.some(
      (current) =>
        Math.abs(current.maxHoursBeforeStart - rule.maxHoursBeforeStart) < 0.0001,
    );
    if (!hasSameWindow) deduped.push(rule);
  }
  return deduped.slice(0, 6);
}

export function computeLeadTimeBoostPercent(
  hoursUntilStart: number,
  rules: LeadTimeSurgeRule[] | undefined,
) {
  if (hoursUntilStart <= 0) return 0;
  const normalized = normalizeLeadTimeSurgeRules(rules);
  for (const rule of normalized) {
    if (hoursUntilStart <= rule.maxHoursBeforeStart) {
      return rule.boostPercent;
    }
  }
  return 0;
}

