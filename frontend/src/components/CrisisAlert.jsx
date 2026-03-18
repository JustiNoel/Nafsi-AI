import { AlertTriangle, X, Phone } from "lucide-react";
export default function CrisisAlert({ crisis, onDismiss }) {
  const isCritical = crisis.severity === "critical";
  return (
    <div className={`mx-4 mt-2 p-4 rounded-xl border-l-4 ${isCritical ? "bg-red-50 border-red-500" : "bg-amber-50 border-amber-500"}`}>
      <div className="flex justify-between items-start">
        <div className="flex gap-2">
          <AlertTriangle className={isCritical ? "text-red-500" : "text-amber-500"} size={20}/>
          <div>
            <p className="font-semibold text-sm">{isCritical ? "Crisis Detected" : "We're Concerned"}</p>
            <p className="text-xs text-gray-600 mt-1">
              {isCritical ? "Please reach out for immediate help. You are not alone." : "It sounds like you might be going through something difficult."}
            </p>
            <a href="tel:+254722178177" className="inline-flex items-center gap-1 text-xs text-white bg-nafsi-green px-3 py-1 rounded-full mt-2">
              <Phone size={12}/> Befrienders Kenya
            </a>
          </div>
        </div>
        <button onClick={onDismiss}><X size={16} className="text-gray-400"/></button>
      </div>
    </div>
  );
}
