class ApiError extends Error {
  constructor(status, message, errors = null, code = null) {
    super(message);
    this.status = status;
    this.errors = errors;
    this.code = code;
  }
}

module.exports = { ApiError };
