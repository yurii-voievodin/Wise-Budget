import SwiftUI

struct OnboardingCurrencyStep: View {
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    private static let currencyOptions: [(code: String, label: String)] = Locale.commonISOCurrencyCodes.map { code in
        let localized = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return (code, "\(code) – \(localized)")
    }

    var body: some View {
        OnboardingStepLayout(
            icon: "dollarsign.circle.fill",
            iconColor: .green,
            title: "Pick your default currency",
            subtitle: "Used for totals and converting transactions made in other currencies. You can change it later in Settings."
        ) {
            Picker("Default currency", selection: $defaultCurrency) {
                ForEach(Self.currencyOptions, id: \.code) { option in
                    Text(option.label).tag(option.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 320)
        }
    }
}

#Preview {
    OnboardingCurrencyStep()
        .frame(width: 580, height: 460)
}
