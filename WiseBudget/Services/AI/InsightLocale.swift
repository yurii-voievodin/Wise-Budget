import Foundation
import FoundationModels

/// Resolves which language and instruction block to use when prompting the
/// Foundation Models LLM, based on the user's current locale and the model's
/// supported languages. Falls back to English when Ukrainian is requested but
/// not yet supported by the on-device model.
enum InsightLocale {

    struct Resolved {
        let identifier: String          // "en" or "uk"
        let monthlyInstructions: String
        let trendsInstructions: String
    }

    static func current() -> Resolved {
        let modelSupportedCodes = Set(
            SystemLanguageModel.default.supportedLanguages
                .compactMap { $0.languageCode?.identifier }
        )
        return resolve(
            userLanguageCode: Locale.current.language.languageCode?.identifier,
            modelSupportedCodes: modelSupportedCodes
        )
    }

    /// Pure resolution logic, exposed for testing. Given the user's language
    /// code and the set of language codes the on-device model supports, returns
    /// the appropriate `Resolved` bundle.
    static func resolve(
        userLanguageCode: String?,
        modelSupportedCodes: Set<String>
    ) -> Resolved {
        if userLanguageCode == "uk" && modelSupportedCodes.contains("uk") {
            return Resolved(
                identifier: "uk",
                monthlyInstructions: monthlyUkrainian,
                trendsInstructions: trendsUkrainian
            )
        }
        return Resolved(
            identifier: "en",
            monthlyInstructions: monthlyEnglish,
            trendsInstructions: trendsEnglish
        )
    }

    // MARK: - English

    private static let monthlyEnglish = """
    You are a concise personal-finance analyst. You will receive a JSON summary \
    of one month of the user's expenses and incomes. Respond with 3 to 5 short \
    bullet points covering: the biggest spending categories, anything that looks \
    unusual, and one concrete suggestion. Use the currency provided in the JSON. \
    Do not invent numbers. Keep the whole response under 120 words.
    """

    private static let trendsEnglish = """
    You are a concise personal-finance analyst. You will receive a JSON summary \
    of spending over several months, broken down by category. Respond in Markdown \
    bullets and cover: 2 to 3 categories with the biggest month-over-month \
    growth, 2 to 3 categories with the biggest drops, any unusual month, and end \
    with one concrete, actionable suggestion. Use the currency provided in the \
    JSON. Do not invent numbers. Keep the whole response under 150 words.
    """

    // MARK: - Ukrainian

    private static let monthlyUkrainian = """
    Ти стислий аналітик особистих фінансів. Отримаєш JSON-підсумок одного місяця \
    витрат і доходів користувача. Відповідай українською. Склади 3–5 коротких \
    пунктів: найбільші категорії витрат, щось незвичне, одна конкретна порада. \
    Використовуй валюту з JSON. Не вигадуй числа. Уся відповідь до 120 слів.
    """

    private static let trendsUkrainian = """
    Ти стислий аналітик особистих фінансів. Отримаєш JSON зі зведенням витрат за \
    кілька місяців із розбивкою за категоріями. Відповідай українською у форматі \
    Markdown-пунктів: 2–3 категорії з найбільшим зростанням місяць до місяця, \
    2–3 категорії з найбільшим падінням, будь-який нетиповий місяць і наприкінці \
    одна конкретна порада. Використовуй валюту з JSON. Не вигадуй числа. Уся \
    відповідь до 150 слів.
    """
}
