import { useState, useEffect } from "react";
import { Phone, Globe } from "lucide-react";
import api from "../services/api";
const SEED = [
  { id:"1", name:"Befrienders Kenya", resource_type:"hotline", country:"Kenya", phone:"+254722178177", url:null, is_free:true, description:"24/7 emotional support" },
  { id:"2", name:"Mentally Aware Nigeria", resource_type:"ngo", country:"Nigeria", phone:null, url:"https://mani.org.ng", is_free:true, description:"Mental health advocacy" },
  { id:"3", name:"SADAG South Africa", resource_type:"hotline", country:"South Africa", phone:"+27800567567", url:"https://sadag.org", is_free:true, description:"24-hour crisis line" },
];
export default function Resources() {
  const [resources, setResources] = useState(SEED);
  const [filter, setFilter] = useState("");
  useEffect(() => { api.get("/resources/").then(r => { if (r.data.length) setResources(r.data); }).catch(() => {}); }, []);
  const filtered = resources.filter(r => r.country.toLowerCase().includes(filter.toLowerCase()) || r.name.toLowerCase().includes(filter.toLowerCase()));
  return (
    <div className="max-w-2xl mx-auto p-6 space-y-4">
      <h1 className="text-2xl font-bold text-nafsi-teal">📋 Mental Health Resources</h1>
      <input className="w-full border rounded-xl px-4 py-2 focus:outline-none focus:ring-2 focus:ring-nafsi-green" placeholder="Search by country or name..." value={filter} onChange={e => setFilter(e.target.value)}/>
      <div className="space-y-3">
        {filtered.map(r => (
          <div key={r.id} className="bg-white border rounded-xl p-4 shadow-sm">
            <div className="flex justify-between items-start">
              <div>
                <h3 className="font-semibold">{r.name}</h3>
                <p className="text-sm text-gray-500">{r.country} · {r.resource_type}</p>
                {r.description && <p className="text-sm text-gray-600 mt-1">{r.description}</p>}
              </div>
              {r.is_free && <span className="text-xs bg-nafsi-light text-nafsi-teal px-2 py-1 rounded-full">Free</span>}
            </div>
            <div className="flex gap-3 mt-3">
              {r.phone && <a href={`tel:${r.phone}`} className="flex items-center gap-1 text-sm text-nafsi-green"><Phone size={14}/>{r.phone}</a>}
              {r.url && <a href={r.url} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-sm text-nafsi-green"><Globe size={14}/>Website</a>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
