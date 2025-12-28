---
layout: home
title: Home
---
<link rel="stylesheet" href="{{ '/assets/css/index.css' | relative_url }}">

<div class="index-layout">
	<aside class="index-sitemap">
		<h2>Sitemap</h2>
		<nav aria-label="Sitemap do site">
			<ul>
				{% for post in site.posts %}
				<li><a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>
				{% endfor %}
			</ul>
		</nav>
	</aside>

  <section class="index-content" markdown="1">
![alt]({{ site.baseurl }}/assets/images/index/icon.png)

👋 Bem-vindo ao alface0x19.

Notas técnicas, tutoriais práticos e decisões reais em Linux, DevOps, homelab e segurança.

📺 Conteúdo complementar em vídeo no YouTube:
[youtube.com/@alface0x19](https://youtube.com/@alface0x19)

Aqui partilho:

<div class="topics-grid">
  <article class="topic-card">
    <h3>🔧 DevOps &amp; SRE</h3>
    <p>Automação, pipelines e observabilidade aplicadas no dia-a-dia.</p>
  </article>
  <article class="topic-card">
    <h3>☸️ Kubernetes</h3>
    <p>Clusters, troubleshooting e boas práticas em produção.</p>
  </article>
  <article class="topic-card">
    <h3>🔐 Segurança &amp; CTFs</h3>
    <p>Relatos de desafios, hardening e investigações de phishing.</p>
  </article>
  <article class="topic-card">
    <h3>📚 Estudos &amp; notas</h3>
    <p>Resumo de cursos, certificações e laboratórios aprendidos.</p>
  </article>
  <article class="topic-card">
    <h3>🏠 Homelab</h3>
    <p>Infraestrutura caseira, self-hosting e automação doméstica.</p>
  </article>
  <article class="topic-card">
    <h3>💡 Tutoriais</h3>
    <p>Passo a passo prático para acelerar projetos técnicos.</p>
  </article>
  <article class="topic-card">
    <h3>🖥️ Linux</h3>
    <p>Dicas de configuração, scripts e produtividade em sistemas Unix.</p>
  </article>
  <article class="topic-card">
    <h3>📝 E muito mais!</h3>
    <p>Notas soltas, experiências e ideias em constante exploração.</p>
  </article>
</div>
  </section>
</div>
