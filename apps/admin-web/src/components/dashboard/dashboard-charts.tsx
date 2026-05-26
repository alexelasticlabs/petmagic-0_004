import styles from "@/components/dashboard-view.module.css";

export function RevenueChart({ xLabels, ariaLabel }: { xLabels: string[]; ariaLabel: string }) {
  const points = "50,142 130,126 210,138 305,102 390,66 472,42 560,18";
  const areaPoints = "50,142 130,126 210,138 305,102 390,66 472,42 560,18 560,196 50,196";
  const yLabels = [
    { y: 18, label: "$30k" },
    { y: 71, label: "$20k" },
    { y: 124, label: "$10k" },
    { y: 196, label: "$0" },
  ];
  const xPositions = [50, 130, 210, 305, 390, 472, 560];

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
          key={label}
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

export function DonutChart({ label }: { label: string }) {
  return (
    <svg viewBox="0 0 180 180" className={styles.donutSvg} aria-hidden="true">
      <circle cx="90" cy="90" r="65" stroke="#18231f" strokeWidth="22" fill="none" />
      <circle
        cx="90"
        cy="90"
        r="65"
        stroke="#14532d"
        strokeWidth="22"
        fill="none"
        strokeDasharray="245 163.4"
        strokeDashoffset="-61.3"
      />
      <circle
        cx="90"
        cy="90"
        r="65"
        stroke="#059669"
        strokeWidth="22"
        fill="none"
        strokeDasharray="114.4 294"
        strokeDashoffset="53.1"
      />
      <circle
        cx="90"
        cy="90"
        r="65"
        stroke="#34d399"
        strokeWidth="22"
        fill="none"
        strokeDasharray="49 359.4"
        strokeDashoffset="102.1"
      />
      <text
        x="90"
        y="86"
        textAnchor="middle"
        fill="#f4fff9"
        fontSize="20"
        fontWeight="800"
        fontFamily="system-ui"
      >
        1 256
      </text>
      <text x="90" y="104" textAnchor="middle" fill="#7f938b" fontSize="10" fontFamily="system-ui">
        {label}
      </text>
    </svg>
  );
}
