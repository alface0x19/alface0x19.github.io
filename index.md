---
layout: home
title: Home
---

<link rel="stylesheet" href="{{ '/assets/css/custom.css' | relative_url }}">

<div class="home-layout">
	<aside class="home-sidebar">
		<h2>Artigos</h2>
		<nav aria-label="Artigos publicados">
			<ul>
				{% for post in site.posts %}
				<li><a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>
				{% endfor %}
			</ul>
		</nav>
	</aside>

	<section class="home-content">
		<header class="home-hero">
			<div class="hero-media">
				<img class="hero-image" src="{{ '/assets/images/index/icon.png' | relative_url }}" alt="Ícone do projeto alface0x19">
			</div>
			<div class="hero-details">
				<p class="home-intro">👋 Bem-vindo ao <strong>alface0x19</strong>. Aqui partilho notas técnicas, experiências reais e projetos no ecossistema Linux, DevOps, homelab e segurança.</p>
				<div class="hero-cta">
					<span>📺 Conteúdo complementar em vídeo:</span>
					<a class="hero-link" href="https://youtube.com/@alface0x19" target="_blank" rel="noopener">youtube.com/@alface0x19</a>
				</div>
			</div>
		</header>

		<section class="home-topics" aria-label="Temas principais">
			<h2>O que vais encontrar</h2>
			<div class="topics-grid">
				<article class="topic-card">
					<h3>🔧 DevOps &amp; SRE</h3>
					<p>Automação, pipelines CI/CD e práticas de observabilidade usadas no dia-a-dia.</p>
				</article>
				<article class="topic-card">
					<h3>☸️ Kubernetes</h3>
					<p>Clusters caseiros, troubleshooting e lições aprendidas em produção.</p>
				</article>
				<article class="topic-card">
					<h3>🔐 Segurança &amp; CTFs</h3>
					<p>Relatos de desafios de segurança, hardening e deteção de fraudes.</p>
				</article>
				<article class="topic-card">
					<h3>🏠 Homelab &amp; Linux</h3>
					<p>Infraestrutura doméstica, self-hosting e setups inspiradores.</p>
				</article>
			</div>
		</section>

		<section class="home-latest" aria-label="Artigos recentes">
			<div class="section-header">
				<h2>Últimos artigos</h2>
				<span class="section-note">Explora todos na lista ao lado.</span>
			</div>
			<div class="latest-grid">
				{% for post in site.posts limit:3 %}
				<article class="post-card">
					<h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
					<p class="post-meta">{{ post.date | date: "%d %b %Y" }}</p>
					<p class="post-excerpt">{{ post.excerpt | strip_html | truncate: 140 }}</p>
					<a class="post-link" href="{{ post.url | relative_url }}">Ler mais →</a>
				</article>
				{% endfor %}
			</div>
		</section>
	</section>
</div>