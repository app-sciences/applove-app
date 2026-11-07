export default function Start() {
  return (
    <div className="narrow">
      <h1>Start a project</h1>
      <p className="muted">Tell us about your app. Funding goals must be under $10,000.</p>
      <form className="form">
        <label>App name<input placeholder="My great app" /></label>
        <label>Description<textarea rows={4} placeholder="What does it do?" /></label>
        <label>Funding goal (USD)<input type="number" min={100} max={9999} placeholder="2500" /></label>
        <button type="button" className="btn">Create project</button>
      </form>
    </div>
  );
}
