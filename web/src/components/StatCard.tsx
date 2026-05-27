interface StatCardProps {
  title: string;
  value: string | number;
  sub?: string;
  color?: 'green' | 'red' | 'blue' | 'orange' | 'purple';
  icon?: string;
}

const colorMap = {
  green: 'bg-green-50 border-green-200 text-green-700',
  red: 'bg-red-50 border-red-200 text-red-700',
  blue: 'bg-blue-50 border-blue-200 text-blue-700',
  orange: 'bg-orange-50 border-orange-200 text-orange-700',
  purple: 'bg-purple-50 border-purple-200 text-purple-700',
};

export function StatCard({ title, value, sub, color = 'green', icon }: StatCardProps) {
  return (
    <div className={`rounded-xl border p-4 ${colorMap[color]}`}>
      <div className="flex items-center gap-2 mb-1">
        {icon && <span className="text-lg">{icon}</span>}
        <p className="text-sm font-medium opacity-80">{title}</p>
      </div>
      <p className="text-2xl font-bold">{value}</p>
      {sub && <p className="text-xs mt-1 opacity-70">{sub}</p>}
    </div>
  );
}
