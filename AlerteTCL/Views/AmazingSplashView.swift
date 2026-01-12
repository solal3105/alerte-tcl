import SwiftUI

struct AmazingSplashView: View {
    @Binding var isActive: Bool
    @Binding var apiReady: Bool
    @State private var animationPhase = 0
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var gradientRotation: Double = 0
    @State private var particleOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var minimumAnimationDone = false
    
    // Particules flottantes
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: CGFloat
        var color: Color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond gradient animé
                animatedBackground
                
                // Particules flottantes
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(particle.opacity * particleOpacity)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: particle.size / 4)
                }
                
                // Contenu central
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo animé
                    ZStack {
                        // Anneaux pulsants
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.cyan.opacity(0.2),
                                            Color.blue.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                                .scaleEffect(ringScale + CGFloat(i) * 0.1 * (pulseScale - 1))
                                .opacity(ringOpacity * (1 - Double(i) * 0.3))
                        }
                        
                        // Cercle principal avec icône
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.5), radius: 30, x: 0, y: 10)
                            .overlay(
                                Image(systemName: "tram.fill")
                                    .font(.system(size: 44, weight: .medium))
                                    .foregroundStyle(.white)
                            )
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }
                    .scaleEffect(pulseScale)
                    
                    // Texte de l'app
                    VStack(spacing: 8) {
                        Text("AlerteTCL")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Transport en temps réel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                    
                    Spacer()
                    
                    // Indicateur de chargement subtil
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(0.8))
                                .frame(width: 8, height: 8)
                                .scaleEffect(animationPhase == i ? 1.3 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                                    value: animationPhase
                                )
                        }
                    }
                    .opacity(textOpacity * 0.8)
                    .padding(.bottom, 60)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                initializeParticles(in: geometry.size)
                startAnimations()
                startParticleAnimation(in: geometry.size)
            }
        }
        .onChange(of: apiReady) { _, ready in
            if ready && minimumAnimationDone {
                dismissSplash()
            }
        }
        .onChange(of: minimumAnimationDone) { _, done in
            if done && apiReady {
                dismissSplash()
            }
        }
    }
    
    // MARK: - Animated Background
    
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.25),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Rotating gradient overlay
            AngularGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.cyan.opacity(0.3),
                    Color.blue.opacity(0.2),
                    Color.purple.opacity(0.3)
                ],
                center: .center,
                angle: .degrees(gradientRotation)
            )
            .blur(radius: 60)
            .opacity(0.5)
            
            // Subtle mesh effect
            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.2),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
            
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Phase 1: Logo apparaît
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Phase 2: Anneaux apparaissent
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }
        
        // Phase 3: Texte apparaît
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
            textOffset = 0
        }
        
        // Phase 4: Particules apparaissent
        withAnimation(.easeIn(duration: 0.8).delay(0.4)) {
            particleOpacity = 1.0
        }
        
        // Animation continue du gradient
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }
        
        // Animation de pulsation continue
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.8)) {
            pulseScale = 1.05
        }
        
        // Indicateur de chargement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animationPhase = 1
        }
        
        // Minimum animation time (2.5 secondes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            minimumAnimationDone = true
        }
    }
    
    private func initializeParticles(in size: CGSize) {
        let colors: [Color] = [.blue, .cyan, .purple, .white]
        particles = (0..<25).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.2...0.6),
                speed: CGFloat.random(in: 0.3...1.0),
                color: colors.randomElement() ?? .white
            )
        }
    }
    
    private func startParticleAnimation(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if isActive == false {
                timer.invalidate()
                return
            }
            
            for i in particles.indices {
                particles[i].y -= particles[i].speed
                particles[i].x += sin(particles[i].y / 50) * 0.5
                
                if particles[i].y < -20 {
                    particles[i].y = size.height + 20
                    particles[i].x = CGFloat.random(in: 0...size.width)
                }
            }
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.5)) {
            logoOpacity = 0
            ringOpacity = 0
            textOpacity = 0
            particleOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isActive = false
            }
        }
    }
    
}

// MARK: - Preview

#Preview {
    AmazingSplashView(isActive: .constant(true), apiReady: .constant(false))
}
