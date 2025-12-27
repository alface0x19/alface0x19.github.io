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

	<section class="home-content" markdown="1">
👋 Bem-vindo ao alface0x19.

Notas técnicas, tutoriais práticos e decisões reais em Linux, DevOps, homelab e segurança.

📺 Conteúdo complementar em vídeo no YouTube:
[youtube.com/@alface0x19](https://youtube.com/@alface0x19)

Aqui partilho:
- 🔧 DevOps & SRE
- ☸️ Kubernetes
- 🔐 Segurança & CTFs
- 📚 Estudos e notas técnicas
- 🏠 Homelab
- 💡 Tutoriais práticos
- 🖥️ Linux
- 📝 E muito mais!
	</section>
</div>