namespace UnivespProject.Application.Auth;

public static class PasswordPolicy
{
    public const int MinLength = 8;
    public const int MaxLength = 128;

    /// <returns>Every rule the password breaks; empty when it is valid.</returns>
    public static IEnumerable<string> Validate(string? password)
    {
        password ??= string.Empty;

        if (password.Length < MinLength)
            yield return $"A senha deve ter no mínimo {MinLength} caracteres.";
        if (password.Length > MaxLength)
            yield return $"A senha deve ter no máximo {MaxLength} caracteres.";
        if (!password.Any(char.IsUpper))
            yield return "A senha deve conter ao menos uma letra maiúscula.";
        if (!password.Any(char.IsLower))
            yield return "A senha deve conter ao menos uma letra minúscula.";
        if (!password.Any(char.IsDigit))
            yield return "A senha deve conter ao menos um número.";
    }
}
