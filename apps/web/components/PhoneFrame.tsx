import type { Project } from "@/lib/projects";

/** Every app preview is rendered inside a phone: bezel, notch, status bar, home indicator. */
export default function PhoneFrame({ project, width = 220 }: { project: Project; width?: number }) {
  const h = project.hue;
  return (
    <div className="phone" style={{ width }}>
      <div className="phone-screen">
        <div className="phone-notch" />
        {project.screenshot ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={project.screenshot} alt={`${project.name} screenshot`} className="phone-shot" />
        ) : (
          <div
            className="mock"
            style={{ background: `linear-gradient(170deg, hsl(${h} 80% 62%), hsl(${(h + 40) % 360} 75% 38%))` }}
          >
            <div className="mock-status">
              <span>9:41</span>
              <span>●●● ▮</span>
            </div>
            <div className="mock-icon">{project.emoji}</div>
            <div className="mock-name">{project.name}</div>
            <div className="mock-tag">{project.tagline}</div>
            <div className="mock-cards">
              <div className="mock-card" />
              <div className="mock-card short" />
              <div className="mock-card" />
            </div>
            <div className="mock-cta">Get started</div>
          </div>
        )}
        <div className="phone-home" />
      </div>
    </div>
  );
}
