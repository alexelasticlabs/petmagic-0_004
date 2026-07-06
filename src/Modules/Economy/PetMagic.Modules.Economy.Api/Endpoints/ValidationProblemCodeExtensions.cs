using System.Text.RegularExpressions;

using FluentValidation.Results;

namespace PetMagic.Modules.Economy.Api.Endpoints;

internal static partial class ValidationProblemCodeExtensions
{
    public static IDictionary<string, string[]> ToValidationCodeDictionary(this ValidationResult validation)
    {
        return validation.Errors
            .GroupBy(error => error.PropertyName)
            .ToDictionary(
                group => group.Key,
                group => group.Select(ToValidationCode).ToArray());
    }

    private static string ToValidationCode(ValidationFailure failure)
    {
        if (ValidationCodeRegex().IsMatch(failure.ErrorMessage))
        {
            return failure.ErrorMessage;
        }

        return failure.ErrorCode switch
        {
            "NotEmptyValidator" or "NotNullValidator" => "validation.required",
            "MaximumLengthValidator" => "validation.max_length",
            "MinimumLengthValidator" => "validation.min_length",
            "ExactLengthValidator" => "validation.length",
            "EmailValidator" => "validation.email",
            "GreaterThanValidator" => "validation.greater_than",
            "GreaterThanOrEqualValidator" => "validation.greater_than_or_equal",
            "LessThanOrEqualValidator" => "validation.less_than_or_equal",
            "InclusiveBetweenValidator" => "validation.inclusive_between",
            "NotEqualValidator" => "validation.not_equal",
            "EqualValidator" => "validation.equal",
            "RegularExpressionValidator" => "validation.pattern",
            "NullValidator" => "validation.must_be_null",
            _ => "validation.invalid"
        };
    }

    [GeneratedRegex(@"^[a-z0-9_]+\.[a-z0-9_.]+$", RegexOptions.Compiled)]
    private static partial Regex ValidationCodeRegex();
}
