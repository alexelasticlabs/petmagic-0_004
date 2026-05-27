import styles from "@/components/dashboard-view.module.css";

type DonutChartItem = {
  color: string;
  count: string;
};

export function RevenueChart({
  xLabels,
  values,
  currencyCode,
  ariaLabel,
}: {
  xLabels: string[];
  values: number[];
  currencyCode: string;
  ariaLabel: string;
}) {
  const xPositions = [50, 130, 210, 305, 390, 472, 560];
  const normalizedValues = xPositions.map((_, index) => values[index] ?? 0);
  const maxValue = Math.max(...normalizedValues, 1);
  const points = normalizedValues
    .map((value, index) => {
      const x = xPositions[index];
      const y = 196 - (value / maxValue) * 178;
      return `${x},${Math.max(18, Math.min(196, Number(y.toFixed(2))))}`;
    })
    .join(" ");
  const areaPoints = `${points} 560,196 50,196`;
  const yLabels = [1, 2 / 3, 1 / 3, 0].map((ratio) => ({
    y: 196 - 178 * ratio,
    label: formatCompactCurrency(maxValue * ratio, currencyCode),
  }));

  return (
    <svg viewBox="0 0 610 240" className={styles.chartSvg} aria-label={ariaLabel}>
      <defs>
        <linearGradient id="dashboardRevenueGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#34d399" stopOpacity="0.28" />
          <stop offset="100%" stopColor="#22c55e" stopOpacity="0" />
        </linearGradient>
      </defs>
      {yLabels.map(({ y }) => (
        <line
          key={y}
          x1="42"
          y1={y}
          x2="570"
          y2={y}
          stroke="#21332d"
          strokeWidth="1"
          strokeDasharray="4 4"
        />
      ))}
      {yLabels.map(({ y, label }) => (
        <text
          key={`y-label-${y}`}
          x="36"
          y={y + 4}
          textAnchor="end"
          fill="#7f938b"
          fontSize="10"
          fontFamily="system-ui"
        >
          {label}
        </text>
      ))}
      <polygon points={areaPoints} fill="url(#dashboardRevenueGradient)" />
      <polyline
        points={points}
        stroke="#34d399"
        strokeWidth="2.4"
        fill="none"
        strokeLinejoin="round"
      />
      {points.split(" ").map((point, index) => {
        const [x, y] = point.split(",").map(Number);
        return (
          <circle
            key={index}
            cx={x}
            cy={y}
            r="3.6"
            fill="#34d399"
            stroke="#050706"
            strokeWidth="1.6"
          />
        );
      })}
      {xPositions.map((x, index) => (
        <text
          key={x}
          x={x}
          y={220}
          textAnchor="middle"
          fill="#7f938b"
          fontSize="10"
          fontFamily="system-ui"
        >
          {xLabels[index]}
        </text>
      ))}
    </svg>
  );
}

export function DonutChart({
  label,
  total,
  items,
}: {
  label: string;
  total: string;
  items: DonutChartItem[];
}) {
  const numericItems = items.map((item) => ({
    color: item.color,
    value: Number.parseInt(item.count.replace(/\s/g, ""), 10) || 0,
  }));
  const totalValue = Math.max(
    1,
    numericItems.reduce((sum, item) => sum + item.value, 0)
  );
  const circumference = 2 * Math.PI * 65;
  let currentOffset = 0;

  return (
    <svg viewBox="0 0 180 180" className={styles.donutSvg} aria-hidden="true">
      <circle cx="90" cy="90" r="65" stroke="#18231f" strokeWidth="22" fill="none" />
      {numericItems.map((item) => {
        const length = (item.value / totalValue) * circumference;
        const circle = (
          <circle
            key={item.color}
            cx="90"
            cy="90"
            r="65"
            stroke={item.color}
            strokeWidth="22"
            fill="none"
            strokeDasharray={`${length} ${circumference - length}`}
            strokeDashoffset={String(-currentOffset)}
          />
        );
        currentOffset += length;
        return circle;
      })}
      <text
        x="90"
        y="86"
        textAnchor="middle"
        fill="#f4fff9"
        fontSize="20"
        fontWeight="800"
        fontFamily="system-ui"
      >
        {total}
      </text>
      <text x="90" y="104" textAnchor="middle" fill="#7f938b" fontSize="10" fontFamily="system-ui">
        {label}
      </text>
    </svg>
  );
}

function formatCompactCurrency(value: number, currencyCode: string) {
  if (value <= 0) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currencyCode,
      maximumFractionDigits: 0,
    }).format(0);
  }

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currencyCode,
    notation: value >= 1000 ? "compact" : "standard",
    maximumFractionDigits: value >= 1000 ? 1 : 0,
  }).format(value);
}
