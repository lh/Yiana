import { useState } from "react";

const PDFPage = ({ scale = 1 }) => (
  <div style={{
    transform: `scale(${scale})`,
    transformOrigin: "top center",
    transition: "transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
    width: 595,
    height: 842,
    background: "#fff",
    color: "#1a1a1a",
    padding: "54px 62px",
    fontFamily: "'Times New Roman', Georgia, serif",
    fontSize: "16.5px",
    lineHeight: 1.7,
    boxSizing: "border-box",
    boxShadow: "0 2px 16px rgba(0,0,0,0.25)",
    borderRadius: 1,
    position: "relative",
    flexShrink: 0,
  }}>
    <div style={{
      position: "absolute", top: 0, right: 0, width: 140, height: 140,
      background: "linear-gradient(225deg, rgba(200,195,185,0.25) 0%, transparent 55%)",
      pointerEvents: "none",
    }} />
    <h2 style={{ fontSize: 30, fontWeight: 400, margin: "0 0 30px 0", fontFamily: "Georgia, serif" }}>Results</h2>
    <p style={{ margin: "0 0 10px" }}><b>65</b> published papers</p>
    <p style={{ margin: "0 0 22px" }}><b>55</b> were excluded as they did not meet our inclusion criteria</p>
    <p style={{ margin: "0 0 8px" }}><b>10</b> studies were identified:</p>
    <ul style={{ margin: "0 0 0 28px", padding: 0, lineHeight: 1.9 }}>
      <li><b>6</b> analyzing ERM</li>
      <li><b>2</b> analyzing MH</li>
      <li><b>1</b> separately analyzing ERM and MH</li>
      <li><b>1</b> analyzing VMT +- MH</li>
    </ul>
    <p style={{ marginTop: 26, marginBottom: 8, fontStyle: "italic" }}>Variety of different methods for:</p>
    <ul style={{ margin: "0 0 0 28px", padding: 0, lineHeight: 1.9 }}>
      <li><b>Assessing metamorphopsia</b> (M-Charts, D-charts, MeMoQ, Amsler chart)</li>
      <li><b>Assessing VA</b> (monocular, binocular)</li>
      <li><b>Assessing VR-QoL</b> (NEI VFQ-25, NEI VFQ-39, VF-14)</li>
      <li><b>Statistical analysis of associations</b> (Spearman correlation, regression)</li>
    </ul>
  </div>
);

const SidebarModePicker = ({ mode, onSetMode }) => (
  <div style={{
    display: "flex",
    margin: "10px 8px 8px",
    background: "rgba(255,255,255,0.06)",
    borderRadius: 6,
    padding: 2,
    gap: 1,
  }}>
    {["Pages", "Addresses"].map((m) => (
      <button
        key={m}
        onClick={() => onSetMode(m)}
        style={{
          flex: 1,
          padding: "4px 0",
          fontSize: 11,
          fontWeight: mode === m ? 600 : 400,
          fontFamily: "-apple-system, sans-serif",
          color: mode === m ? "#fff" : "#888",
          background: mode === m ? "#4a9eff" : "transparent",
          border: "none",
          borderRadius: 5,
          cursor: "pointer",
          transition: "all 0.15s ease",
        }}
      >{m}</button>
    ))}
  </div>
);

const PageThumb = ({ num, active }) => (
  <div style={{ textAlign: "center", marginBottom: 14, cursor: "pointer" }}>
    <div style={{
      width: 76, height: 100,
      background: active ? "#fff" : "#eaeaea",
      border: active ? "2.5px solid #4a9eff" : "2px solid transparent",
      borderRadius: 3, padding: 6, boxSizing: "border-box",
      fontSize: 6.5, color: "#444", lineHeight: 1.35,
      fontFamily: "Georgia, serif", overflow: "hidden",
      boxShadow: active ? "0 2px 8px rgba(74,158,255,0.2)" : "0 1px 4px rgba(0,0,0,0.12)",
    }}>
      {num === 1 && <>
        <div style={{ fontWeight: 400, fontSize: 8.5, marginBottom: 3 }}>Results</div>
        <div><b>65</b> published papers</div>
        <div style={{ marginTop: 1.5 }}><b>55</b> were excluded...</div>
        <div style={{ marginTop: 1.5 }}><b>10</b> studies identified</div>
        <div style={{ marginTop: 1.5, fontSize: 5.5, color: "#888" }}>• 6 analyzing ERM</div>
      </>}
      {num === 2 && <>
        <div style={{ fontSize: 8.5, marginBottom: 4 }}>Discussion</div>
        {[...Array(6)].map((_, i) => (
          <div key={i} style={{ background: "#d4d4d4", height: 3.5, borderRadius: 2, marginBottom: 2.5, width: i === 5 ? "55%" : "100%" }} />
        ))}
      </>}
      {num === 3 && <>
        <div style={{ fontSize: 8.5, marginBottom: 4 }}>References</div>
        {[...Array(8)].map((_, i) => (
          <div key={i} style={{ background: "#d4d4d4", height: 2.5, borderRadius: 1, marginBottom: 2, width: i === 7 ? "35%" : "100%" }} />
        ))}
      </>}
    </div>
    <div style={{
      color: active ? "#ddd" : "#777", fontSize: 10, marginTop: 5,
      fontFamily: "-apple-system, sans-serif", fontWeight: active ? 500 : 400,
    }}>Page {num}</div>
  </div>
);

const AddressCard = ({ name, lines }) => (
  <div style={{
    background: "rgba(255,255,255,0.04)",
    border: "1px solid rgba(255,255,255,0.08)",
    borderRadius: 6, padding: "10px 10px", margin: "0 8px 10px",
  }}>
    <div style={{ color: "#ccc", fontSize: 10, fontWeight: 600, marginBottom: 4, fontFamily: "-apple-system, sans-serif" }}>{name}</div>
    {lines.map((l, i) => (
      <div key={i} style={{ color: "#888", fontSize: 9.5, lineHeight: 1.5, fontFamily: "-apple-system, sans-serif" }}>{l}</div>
    ))}
  </div>
);

const Icon = ({ type, size = 14, color = "#b0b0b0" }) => {
  const paths = {
    back: <path d="M15 18l-6-6 6-6" stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" />,
    sidebar: <><rect x="3" y="3" width="18" height="18" rx="2" stroke={color} strokeWidth="1.5" fill="none"/><line x1="9" y1="3" x2="9" y2="21" stroke={color} strokeWidth="1.5"/></>,
    sidebarActive: <><rect x="3" y="3" width="18" height="18" rx="2" stroke="#4a9eff" strokeWidth="1.5" fill="none"/><rect x="3" y="3" width="6" height="18" rx="2" fill="rgba(74,158,255,0.3)" stroke="#4a9eff" strokeWidth="1.5"/><line x1="9" y1="3" x2="9" y2="21" stroke="#4a9eff" strokeWidth="1.5"/></>,
    chevLeft: <path d="M14 16l-4-4 4-4" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>,
    chevRight: <path d="M10 16l4-4-4-4" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>,
    zoomIn: <><circle cx="11" cy="11" r="6" stroke={color} strokeWidth="1.5" fill="none"/><line x1="11" y1="8" x2="11" y2="14" stroke={color} strokeWidth="1.5"/><line x1="8" y1="11" x2="14" y2="11" stroke={color} strokeWidth="1.5"/><line x1="15.5" y1="15.5" x2="20" y2="20" stroke={color} strokeWidth="1.5"/></>,
    zoomOut: <><circle cx="11" cy="11" r="6" stroke={color} strokeWidth="1.5" fill="none"/><line x1="8" y1="11" x2="14" y2="11" stroke={color} strokeWidth="1.5"/><line x1="15.5" y1="15.5" x2="20" y2="20" stroke={color} strokeWidth="1.5"/></>,
    fitHeight: <><rect x="6" y="2" width="12" height="20" rx="1" stroke={color} strokeWidth="1.5" fill="none"/><line x1="12" y1="5" x2="12" y2="19" stroke={color} strokeWidth="1" strokeDasharray="2 2"/><polyline points="9 6 12 3 15 6" stroke={color} strokeWidth="1.3" fill="none" strokeLinecap="round"/><polyline points="9 18 12 21 15 18" stroke={color} strokeWidth="1.3" fill="none" strokeLinecap="round"/></>,
    fitWidth: <><rect x="2" y="5" width="20" height="14" rx="1" stroke={color} strokeWidth="1.5" fill="none"/><line x1="5" y1="12" x2="19" y2="12" stroke={color} strokeWidth="1" strokeDasharray="2 2"/><polyline points="6 9 3 12 6 15" stroke={color} strokeWidth="1.3" fill="none" strokeLinecap="round"/><polyline points="18 9 21 12 18 15" stroke={color} strokeWidth="1.3" fill="none" strokeLinecap="round"/></>,
    folder: <path d="M3 7V5a2 2 0 012-2h4l2 2h6a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2V7z" stroke={color} strokeWidth="1.5" fill="none"/>,
    share: <><path d="M4 12v6a2 2 0 002 2h12a2 2 0 002-2v-6" stroke={color} strokeWidth="1.5" fill="none"/><polyline points="16 6 12 2 8 6" stroke={color} strokeWidth="1.5" fill="none"/><line x1="12" y1="2" x2="12" y2="14" stroke={color} strokeWidth="1.5"/></>,
    info: <><circle cx="12" cy="12" r="9" stroke={color} strokeWidth="1.5" fill="none"/><line x1="12" y1="11" x2="12" y2="16" stroke={color} strokeWidth="1.5"/><circle cx="12" cy="8" r="0.5" fill={color}/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>{paths[type]}</svg>;
};

const Btn = ({ children, style, title, ...props }) => (
  <button title={title} style={{
    background: "none", border: "none", color: "#b0b0b0", cursor: "pointer",
    display: "flex", alignItems: "center", gap: 4, padding: "4px 5px",
    borderRadius: 4, fontSize: 12, fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
    ...style,
  }} {...props}>{children}</button>
);

const TextBtn = ({ children, color = "#4a9eff", title }) => (
  <span title={title} style={{
    color, fontSize: 11.5, cursor: "pointer", fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
    fontWeight: 400, display: "flex", alignItems: "center", gap: 3, whiteSpace: "nowrap",
  }}>{children}</span>
);

const Sep = () => <div style={{ width: 1, height: 16, background: "#444", margin: "0 3px", flexShrink: 0 }} />;

export default function App() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [fitMode, setFitMode] = useState("height");
  const [sidebarMode, setSidebarMode] = useState("Pages");

  const SIDEBAR_W = 120;
  const CONTENT_H = 560;
  const PDF_W = 595;
  const PDF_H = 842;

  const contentW = sidebarOpen ? 920 - SIDEBAR_W : 920;
  const scaleByHeight = CONTENT_H / PDF_H;
  const scaleByWidth = (contentW - 40) / PDF_W;
  const pdfScale = fitMode === "height"
    ? Math.min(scaleByHeight, scaleByWidth)
    : scaleByWidth;

  return (
    <div style={{
      minHeight: "100vh",
      background: "#111",
      fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif",
      color: "#e0e0e0",
      padding: "20px",
    }}>
      {/* Demo controls */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "center",
        gap: 8, marginBottom: 8, flexWrap: "wrap",
      }}>
        <span style={{ color: "#555", fontSize: 11, textTransform: "uppercase", letterSpacing: 1.5, fontWeight: 600, marginRight: 4 }}>
          Option 2 — Final
        </span>
        <button onClick={() => setSidebarOpen(!sidebarOpen)} style={{
          background: sidebarOpen ? "rgba(74,158,255,0.15)" : "rgba(255,255,255,0.06)",
          color: sidebarOpen ? "#4a9eff" : "#888",
          border: "1px solid", borderColor: sidebarOpen ? "rgba(74,158,255,0.3)" : "rgba(255,255,255,0.08)",
          borderRadius: 8, padding: "7px 16px", fontSize: 12, fontWeight: 500, cursor: "pointer",
          fontFamily: "-apple-system, sans-serif",
        }}>
          {sidebarOpen ? "◧ Sidebar Open" : "▭ Sidebar Closed"}
        </button>
        <button onClick={() => setFitMode(fitMode === "height" ? "width" : "height")} style={{
          background: "rgba(255,255,255,0.06)", color: "#888",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: 8, padding: "7px 16px", fontSize: 12, fontWeight: 500, cursor: "pointer",
          fontFamily: "-apple-system, sans-serif",
        }}>
          {fitMode === "height" ? "↕ Fit Height" : "↔ Fit Width"}
        </button>
      </div>

      {/* Element annotation */}
      <div style={{ maxWidth: 680, margin: "0 auto 16px", textAlign: "center" }}>
        <p style={{ color: "#555", fontSize: 11, lineHeight: 1.7, margin: 0, fontFamily: "-apple-system, sans-serif" }}>
          <span style={{ color: "#888" }}>Row 1:</span> B1a Back · Title · B3a Manage Pages · B3b Export PDF · B3c Info
          &nbsp;&nbsp;·&nbsp;&nbsp;
          <span style={{ color: "#888" }}>Row 2:</span> B4a Sidebar · B4b Page Nav · B4c/d Zoom · B4e/f Fit
          &nbsp;&nbsp;·&nbsp;&nbsp;
          <span style={{ color: "#888" }}>Sidebar:</span> C1a Picker · C1b/c Thumbs or Addresses
        </p>
      </div>

      {/* Mock window */}
      <div style={{ maxWidth: 960, margin: "0 auto" }}>
        <div style={{
          borderRadius: 10, overflow: "hidden",
          border: "1px solid rgba(255,255,255,0.08)",
          background: "#1e1e1e",
          boxShadow: "0 8px 40px rgba(0,0,0,0.5)",
        }}>
          {/* Row 1: Traffic lights + back + title + actions */}
          <div style={{
            background: "#2a2a2a",
            display: "flex", alignItems: "center", justifyContent: "space-between",
            padding: "0 12px", height: 36,
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <div style={{ display: "flex", gap: 8, marginRight: 8 }}>
                <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#ff5f57" }} />
                <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#febc2e" }} />
                <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#28c840" }} />
              </div>
              <Btn title="B1a: Back"><Icon type="back" size={15} /></Btn>
              <span style={{ color: "#e0e0e0", fontSize: 13, fontWeight: 500 }}>Metamorphosis</span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <TextBtn title="B3a: Manage Pages"><Icon type="folder" size={12} color="#4a9eff" /><span style={{ fontSize: 11 }}>Manage Pages</span></TextBtn>
              <TextBtn title="B3b: Export PDF"><Icon type="share" size={12} color="#4a9eff" /><span style={{ fontSize: 11 }}>Export PDF</span></TextBtn>
              <TextBtn title="B3c: Info toggle (opens right sidebar overlay)"><Icon type="info" size={12} color="#4a9eff" /><span style={{ fontSize: 11 }}>Info</span></TextBtn>
            </div>
          </div>

          {/* Row 2: Sidebar toggle | centred page nav | zoom + fit */}
          <div style={{
            background: "#2a2a2a",
            borderBottom: "1px solid #1a1a1a",
            display: "grid", gridTemplateColumns: "1fr auto 1fr",
            alignItems: "center", padding: "0 12px", height: 30,
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Btn onClick={() => setSidebarOpen(!sidebarOpen)} title="B4a: Toggle left sidebar">
                {sidebarOpen ? <Icon type="sidebarActive" size={13} /> : <Icon type="sidebar" size={13} />}
              </Btn>
            </div>
            {/* B4b: centred to window */}
            <div style={{
              display: "flex", alignItems: "center", gap: 3,
              background: "rgba(255,255,255,0.05)", borderRadius: 5, padding: "2px 8px",
            }}>
              <Btn title="Previous page"><Icon type="chevLeft" size={12} /></Btn>
              <span style={{ color: "#b0b0b0", fontSize: 11, minWidth: 44, textAlign: "center", fontFamily: "-apple-system, sans-serif" }}>1 of 3</span>
              <Btn title="Next page"><Icon type="chevRight" size={12} /></Btn>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 4, justifyContent: "flex-end" }}>
              <Btn title="B4d: Zoom out"><Icon type="zoomOut" size={13} /></Btn>
              <Btn title="B4c: Zoom in"><Icon type="zoomIn" size={13} /></Btn>
              <Btn
                onClick={() => setFitMode(fitMode === "height" ? "width" : "height")}
                title={fitMode === "height" ? "B4e: Fit to height (active) — click for fit to width" : "B4f: Fit to width (active) — click for fit to height"}
              >
                {fitMode === "height" ? <Icon type="fitHeight" size={14} /> : <Icon type="fitWidth" size={14} />}
              </Btn>
            </div>
          </div>

          {/* Content area */}
          <div style={{ display: "flex", height: CONTENT_H, overflow: "hidden" }}>
            {/* C1: Left sidebar */}
            <div style={{
              width: sidebarOpen ? SIDEBAR_W : 0,
              minWidth: sidebarOpen ? SIDEBAR_W : 0,
              background: "#252525",
              borderRight: sidebarOpen ? "1px solid #333" : "none",
              overflow: "hidden",
              transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
              display: "flex",
              flexDirection: "column",
            }}>
              {/* C1a: Pages | Addresses picker */}
              <SidebarModePicker mode={sidebarMode} onSetMode={setSidebarMode} />

              {/* C1b: Scroll area */}
              <div style={{
                flex: 1, overflowY: "auto",
                display: "flex", flexDirection: "column", alignItems: "center",
                paddingTop: 6,
              }}>
                {sidebarMode === "Pages" ? (
                  <>
                    <PageThumb num={1} active={true} />
                    <PageThumb num={2} active={false} />
                    <PageThumb num={3} active={false} />
                  </>
                ) : (
                  <>
                    <AddressCard name="Patient" lines={["Mr J. Smith", "42 Oak Avenue", "London SW1A 1AA"]} />
                    <AddressCard name="GP Surgery" lines={["Dr A. Patel", "Riverside Practice", "12 High Street", "London SE1 7PB"]} />
                  </>
                )}
              </div>
            </div>

            {/* B5: PDF viewport */}
            <div style={{
              flex: 1, background: "#3a3a3a",
              display: "flex", justifyContent: "center",
              alignItems: fitMode === "height" ? "center" : "flex-start",
              overflow: fitMode === "width" ? "auto" : "hidden",
              padding: fitMode === "height" ? 0 : "16px 0",
              transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
            }}>
              <PDFPage scale={pdfScale} />
            </div>
          </div>
        </div>
      </div>

      {/* Coverage checklist */}
      <div style={{
        maxWidth: 640, margin: "24px auto 0", padding: "16px 20px",
        background: "rgba(255,255,255,0.03)",
        border: "1px solid rgba(255,255,255,0.06)",
        borderRadius: 8,
      }}>
        <p style={{
          color: "#666", fontSize: 10, textTransform: "uppercase", letterSpacing: 1.2,
          fontWeight: 600, margin: "0 0 10px", fontFamily: "-apple-system, sans-serif",
        }}>Component map coverage — Screen B/C/D</p>
        <div style={{
          display: "grid", gridTemplateColumns: "1fr 1fr",
          gap: "3px 24px", fontSize: 11.5, fontFamily: "-apple-system, sans-serif",
          color: "#888", lineHeight: 1.8,
        }}>
          <div><span style={{ color: "#28c840" }}>✓</span> B1a Back button</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B4a Sidebar toggle</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B3a Manage Pages</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B4b Page navigator</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B3b Export PDF</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B4c Zoom in</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B3c Info toggle</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B4d Zoom out</div>
          <div><span style={{ color: "#28c840" }}>✓</span> C1a Mode picker</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B4e/f Fit toggle</div>
          <div><span style={{ color: "#28c840" }}>✓</span> C1b Thumbnail scroll</div>
          <div><span style={{ color: "#28c840" }}>✓</span> B5 PDF content</div>
          <div><span style={{ color: "#28c840" }}>✓</span> C1c Thumbnail cells</div>
          <div style={{ color: "#555" }}>— B2/B2a Path bar <span style={{ fontSize: 10 }}>(removed)</span></div>
          <div style={{ color: "#555" }}>— D1 Info panel <span style={{ fontSize: 10 }}>(overlay, unchanged)</span></div>
          <div style={{ color: "#555" }}>— B6 Dead space <span style={{ fontSize: 10 }}>(eliminated)</span></div>
          <div style={{ color: "#555" }}>— E Manage Pages <span style={{ fontSize: 10 }}>(modal, unchanged)</span></div>
        </div>
      </div>
    </div>
  );
}
