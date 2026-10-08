@{
  ExcludeRules = @(
    # Interactive installer: output is meant for the console, not the pipeline.
    'PSAvoidUsingWriteHost'
    # Internal helpers, not a public cmdlet surface; the verbs and nouns are chosen for readability.
    'PSUseShouldProcessForStateChangingFunctions'
    'PSUseSingularNouns'
    'PSProvideCommentHelp'
    'PSAvoidUsingPositionalParameters'
    'PSAvoidOverwritingBuiltInCmdlets'
    # Reports parameters that are only read from nested functions.
    'PSReviewUnusedParameter'
  )
}
