// index.js - Landing page functionality

// Navbar scroll effect
window.addEventListener('scroll', function() {
    document.getElementById('navbar').classList.toggle('scrolled', window.scrollY > 50);
});

// Hamburger menu
document.getElementById('hamburger').addEventListener('click', function() {
    var links = document.getElementById('navLinks');
    links.classList.toggle('open');
    this.innerHTML = links.classList.contains('open') ? '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
});

// If logged in, redirect directly to dashboard instead of showing landing page
(function() {
    if (isLoggedIn()) {
        window.location.href = 'home.html';
    }
})();

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(function(a) {
    a.addEventListener('click', function(e) {
        var target = document.querySelector(this.getAttribute('href'));
        if (target) {
            e.preventDefault();
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            var links = document.getElementById('navLinks');
            if (links.classList.contains('open')) {
                links.classList.remove('open');
                document.getElementById('hamburger').innerHTML = '<i class="fas fa-bars"></i>';
            }
        }
    });
});

// Intersection observer for fade-in animations
var fadeObs = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
        if (e.isIntersecting) {
            e.target.classList.add('visible');
            fadeObs.unobserve(e.target);
        }
    });
}, { threshold: 0.1 });
document.querySelectorAll('.fade-in, .slide-up').forEach(function(el) {
    fadeObs.observe(el);
});

// Animated counter
var counterObs = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
        if (e.isIntersecting) {
            var el = e.target;
            var target = parseInt(el.getAttribute('data-target')) || 0;
            var duration = 2000;
            var startTime = null;
            function step(timestamp) {
                if (!startTime) startTime = timestamp;
                var progress = Math.min((timestamp - startTime) / duration, 1);
                var eased = 1 - Math.pow(1 - progress, 3);
                el.textContent = Math.floor(eased * target) + '+';
                if (progress < 1) requestAnimationFrame(step);
            }
            requestAnimationFrame(step);
            counterObs.unobserve(el);
        }
    });
}, { threshold: 0.5 });
document.querySelectorAll('[data-target]').forEach(function(el) {
    counterObs.observe(el);
});

// Typing effect — education-relevant words only
var words = ['Dream University', 'Best Scholarship', 'Perfect Program', 'Bright Future'];
var wordIndex = 0, charIndex = 0, isDeleting = false;
var typingEl = document.getElementById('typingTarget');
function typeEffect() {
    if (!typingEl) return;
    var current = words[wordIndex];
    if (isDeleting) { charIndex--; } else { charIndex++; }
    typingEl.textContent = current.substring(0, charIndex);
    var delay = isDeleting ? 40 : 80;
    if (!isDeleting && charIndex === current.length) { delay = 2500; isDeleting = true; }
    else if (isDeleting && charIndex === 0) { isDeleting = false; wordIndex = (wordIndex + 1) % words.length; delay = 400; }
    setTimeout(typeEffect, delay);
}
setTimeout(typeEffect, 2000);

// Load stats counts - Using predefined data (50+ Universities, 100+ Scholarships)
async function loadStats() {
    var uniEl = document.querySelector('[data-target="50"]');
    var schEl = document.querySelector('[data-target="100"]');
    if (uniEl) {
        animateCounter(uniEl, 50);
    }
    if (schEl) {
        animateCounter(schEl, 100);
    }
}

function animateCounter(el, target) {
    var duration = 1500;
    var startTime = null;
    function step(timestamp) {
        if (!startTime) startTime = timestamp;
        var progress = Math.min((timestamp - startTime) / duration, 1);
        var eased = 1 - Math.pow(1 - progress, 3);
        el.textContent = Math.floor(eased * target) + '+';
        if (progress < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
}

loadStats();
